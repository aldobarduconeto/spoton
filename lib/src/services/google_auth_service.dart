import 'package:spoton/src/services/auth_gateway.dart';
import 'package:spoton/src/services/google_services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Firebase Authentication por e-mail/senha e Google, com perfil no Firestore.
class GoogleAuthService implements AuthGateway {
  GoogleAuthService._();
  static final GoogleAuthService instance = GoogleAuthService._();

  bool _googleInitialized = false;
  @override
  bool get isAvailable => GoogleServices.isInitialized;
  @override
  bool get supportsGoogle =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  void _requireFirebase() {
    if (!isAvailable) throw FirebaseAuthException(code: 'not-configured');
  }

  @override
  Future<void> signIn(String email, String password) async {
    _requireFirebase();
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> register(String name, String email, String password) async {
    _requireFirebase();
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // Account creation already succeeded. A profile/network failure must not
    // present it as a failed registration and invite a duplicate account attempt.
    try {
      await result.user?.updateDisplayName(name.trim());
    } catch (error) {
      debugPrint('Conta criada; atualização do nome pendente: $error');
    }
    await _saveProfile(result.user, name: name.trim());
    try {
      await sendVerification();
    } catch (error) {
      debugPrint('Conta criada; envio de verificação pendente: $error');
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    _requireFirebase();
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      if (error.code != 'user-not-found') rethrow;
    }
  }

  @override
  Future<void> signInGoogle() async {
    await signInWithGoogle();
  }

  String _profileName(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Minha conta';
    return text.length > 80 ? text.substring(0, 80) : text;
  }

  Future<void> _saveProfile(User? user, {String? name}) async {
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
            'uid': user.uid,
            'displayName': _profileName(name ?? user.displayName),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 5));
    } catch (error) {
      debugPrint(
        'Sessão autenticada; sincronização do perfil pendente: $error',
      );
    }
  }

  FirebaseAuth get _auth => FirebaseAuth.instance;
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.userChanges();

  Future<UserCredential> signInWithGoogle() async {
    _requireFirebase();
    late final UserCredential result;
    if (kIsWeb) {
      result = await _auth.signInWithPopup(GoogleAuthProvider());
    } else if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      final googleSignIn = GoogleSignIn.instance;
      if (!_googleInitialized) {
        await googleSignIn.initialize();
        _googleInitialized = true;
      }
      final googleUser = await googleSignIn.authenticate();
      final credential = GoogleAuthProvider.credential(
        idToken: googleUser.authentication.idToken,
      );
      result = await _auth.signInWithCredential(credential);
    } else {
      throw UnsupportedError(
        'O login Google está habilitado para Android, iOS e Web. '
        'Para desktop, configure um fluxo OAuth específico da plataforma.',
      );
    }

    if (result.additionalUserInfo?.isNewUser == true) {
      await _saveProfile(result.user);
    }
    return result;
  }

  DateTime? _verificationSentAt;
  String? _verificationUser;
  int get verificationCooldown {
    if (_verificationUser != currentUser?.uid || _verificationSentAt == null)
      return 0;
    final seconds =
        60 - DateTime.now().difference(_verificationSentAt!).inSeconds;
    return seconds > 0 ? seconds : 0;
  }

  Future<void> sendVerification() async {
    _requireFirebase();
    final user = currentUser;
    if (user == null || user.emailVerified) return;
    if (verificationCooldown > 0) {
      throw FirebaseAuthException(code: 'too-many-requests');
    }
    await user.sendEmailVerification();
    _verificationUser = user.uid;
    _verificationSentAt = DateTime.now();
  }

  Future<void> reloadUser() async {
    _requireFirebase();
    await currentUser?.reload();
    if (currentUser?.emailVerified == true) await currentUser?.getIdToken(true);
  }

  Future<void> updateName(String name) async {
    final value = name.trim();
    if (value.length < 2 || value.length > 80)
      throw ArgumentError('Nome inválido');
    final user = currentUser;
    if (user == null) throw FirebaseAuthException(code: 'user-token-expired');
    if (user.displayName == value) return;
    await user.updateDisplayName(value);
    await _saveProfile(user, name: value);
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final user = currentUser;
    if (user == null || user.email == null)
      throw FirebaseAuthException(code: 'user-token-expired');
    if (newPassword.length < 8)
      throw FirebaseAuthException(code: 'weak-password');
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      ),
    );
    await user.updatePassword(newPassword);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (_googleInitialized &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (error) {
        debugPrint('Limpeza da sessão Google pendente: $error');
      }
    }
  }
}

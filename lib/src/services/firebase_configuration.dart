import 'package:firebase_core/firebase_core.dart';

/// Public Firebase application identifiers, supplied by FlutterFire or dart-define.
/// Never put service-account keys or payment secrets here.
class FirebaseConfiguration {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const useEmulators = bool.fromEnvironment('FIREBASE_EMULATORS');
  static const emulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );
  static FirebaseOptions? get options => apiKey.isEmpty
      ? null
      : const FirebaseOptions(
          apiKey: apiKey,
          appId: String.fromEnvironment('FIREBASE_APP_ID'),
          messagingSenderId: String.fromEnvironment(
            'FIREBASE_MESSAGING_SENDER_ID',
          ),
          projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
          authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
          storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
          iosBundleId: String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
        );
}

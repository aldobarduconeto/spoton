import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:spoton/src/services/auth_errors.dart';
import 'package:spoton/src/services/google_auth_service.dart';
import 'package:spoton/src/views/auth.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final auth = GoogleAuthService.instance;
  late final Stream<User?> users;
  final name = TextEditingController();
  bool busy = false;
  Timer? timer;
  String? message;

  @override
  void initState() {
    super.initState();
    users = auth.authStateChanges;
    name.text = auth.currentUser?.displayName ?? '';
    scheduleCooldown();
  }

  void scheduleCooldown() {
    timer?.cancel();
    final remaining = auth.verificationCooldown;
    if (remaining > 0) {
      timer = Timer(Duration(seconds: remaining + 1), () {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    name.dispose();
    super.dispose();
  }

  Future<void> run(Future<void> Function() action, String success) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
      if (mounted) setState(() => message = success);
    } catch (error) {
      if (mounted) setState(() => message = authErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => busy = false);
        scheduleCooldown();
      }
    }
  }

  Future<void> passwordDialog() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final form = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alterar senha'),
        content: Form(
          key: form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: current,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha atual'),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Informe sua senha atual.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: next,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Nova senha'),
                  validator: (v) => (v ?? '').length < 8
                      ? 'Use pelo menos 8 caracteres.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirm,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar nova senha',
                  ),
                  validator: (v) =>
                      v != next.text ? 'As senhas não coincidem.' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    final oldPassword = current.text;
    final newPassword = next.text;
    // Aguarda a animação de saída antes de descartar os controladores do diálogo.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    current.dispose();
    next.dispose();
    confirm.dispose();
    if (accepted == true && mounted) {
      await run(
        () => auth.changePassword(oldPassword, newPassword),
        'Senha alterada.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Minha conta')),
    body: StreamBuilder<User?>(
      stream: users,
      initialData: auth.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null)
          return Center(
            child: FilledButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const AuthPage()),
              ),
              child: const Text('Entrar ou criar conta'),
            ),
          );
        final passwordUser = user.providerData.any(
          (p) => p.providerId == 'password',
        );
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(Icons.account_circle, size: 72),
                const SizedBox(height: 16),
                Text(user.email ?? 'Conta Google', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                TextField(
                  controller: name,
                  enabled: !busy,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Seu nome'),
                ),
                FilledButton(
                  onPressed: busy
                      ? null
                      : () {
                          if (name.text.trim().length < 2) {
                            setState(
                              () =>
                                  message = 'Informe pelo menos 2 caracteres.',
                            );
                            return;
                          }
                          run(
                            () => auth.updateName(name.text),
                            'Nome atualizado.',
                          );
                        },
                  child: const Text('Salvar nome'),
                ),
                const SizedBox(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    user.emailVerified
                        ? Icons.verified
                        : Icons.mark_email_unread_outlined,
                  ),
                  title: Text(
                    user.emailVerified
                        ? 'E-mail verificado'
                        : 'Verifique seu e-mail',
                  ),
                  subtitle: user.emailVerified
                      ? null
                      : const Text(
                          'Abra o link recebido e atualize a verificação abaixo.',
                        ),
                ),
                if (!user.emailVerified) ...[
                  OutlinedButton(
                    onPressed: busy || auth.verificationCooldown > 0
                        ? null
                        : () => run(
                            auth.sendVerification,
                            'E-mail de verificação enviado.',
                          ),
                    child: Text(
                      auth.verificationCooldown > 0
                          ? 'Aguarde um minuto para reenviar'
                          : 'Enviar e-mail de verificação',
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => run(
                            auth.reloadUser,
                            'Status atualizado. Se ainda não foi confirmado, abra o link no e-mail.',
                          ),
                    child: const Text('Já verifiquei meu e-mail'),
                  ),
                ],
                if (passwordUser)
                  OutlinedButton.icon(
                    onPressed: busy ? null : passwordDialog,
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Alterar senha'),
                  ),
                if (busy) const LinearProgressIndicator(),
                if (message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Semantics(liveRegion: true, child: Text(message!)),
                  ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () => run(auth.signOut, 'Você saiu da conta.'),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sair da conta'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

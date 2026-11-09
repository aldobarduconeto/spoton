import 'package:flutter/material.dart';
import 'package:spoton/src/views/account.dart';
import 'package:flutter/services.dart';
import 'package:spoton/src/services/auth_gateway.dart';
import 'package:spoton/src/services/auth_errors.dart';
import 'package:spoton/src/services/google_auth_service.dart';
import 'package:spoton/src/views/widgets/colors.dart';

enum AuthMode { login, register, reset }

class AuthPage extends StatefulWidget {
  final AuthGateway? authService;
  final AuthMode initialMode;
  const AuthPage({
    super.key,
    this.authService,
    this.initialMode = AuthMode.login,
  });
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late AuthMode _mode;
  late final AuthGateway _auth;
  bool _busy = false, _hidePassword = true, _hideConfirm = true;
  String? _error, _notice;
  bool get _register => _mode == AuthMode.register;
  bool get _reset => _mode == AuthMode.reset;
  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _auth = widget.authService ?? GoogleAuthService.instance;
  }

  @override
  void dispose() {
    for (final controller in [_name, _email, _password, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changeMode(AuthMode mode) {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final email = _email.text;
    final name = _name.text;
    _form.currentState?.reset();
    _email.text = email;
    _name.text = name;
    setState(() {
      _mode = mode;
      _error = null;
      _notice = null;
      _password.clear();
      _confirm.clear();
      _hidePassword = true;
      _hideConfirm = true;
    });
  }

  Future<void> _submit({bool google = false}) async {
    if (_busy || !_auth.isAvailable) return;
    if (!google && !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      if (google) {
        await _auth.signInGoogle();
      } else if (_reset) {
        await _auth.resetPassword(_email.text.trim());
      } else if (_register) {
        await _auth.register(
          _name.text.trim(),
          _email.text.trim(),
          _password.text,
        );
      } else {
        await _auth.signIn(_email.text.trim(), _password.text);
      }
      if (!mounted) return;
      setState(() => _busy = false);
      if (_reset && !google) {
        setState(
          () => _notice = 'Se houver uma conta com esse e-mail, você receberá as instruções para redefinir a senha.',
        );
      } else {
        TextInput.finishAutofillContext();
        if (_register && !google && widget.authService == null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<bool>(builder: (_) => const AccountPage()),
          );
        } else {
          Navigator.of(context).pop(true);
        }
      }
    } catch (error) {
      if (mounted)
        setState(() {
          _busy = false;
          _error = authErrorMessage(error);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _reset
        ? 'Esqueceu a senha?'
        : _register
        ? 'Seu próximo encontro\ncomeça aqui.'
        : 'Bom ter você\npor aqui.';
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Sua conta Spoton')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: AppColors.brandGradient,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(
                            Icons.radar_rounded,
                            size: 44,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _reset
                            ? 'Informe seu e-mail para receber um link de recuperação.'
                            : _register
                            ? 'Crie sua conta para publicar eventos e guardar seus ingressos.'
                            : 'Entre para acompanhar seus ingressos e criar novas experiências.',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (!_reset) ...[
                        SegmentedButton<AuthMode>(
                          segments: const [
                            ButtonSegment(
                              value: AuthMode.login,
                              label: Text('Entrar'),
                            ),
                            ButtonSegment(
                              value: AuthMode.register,
                              label: Text('Criar conta'),
                            ),
                          ],
                          selected: {_mode},
                          onSelectionChanged: _busy
                              ? null
                              : (selection) => _changeMode(selection.first),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (!_auth.isAvailable) ...[
                        _status(
                          'O acesso à conta ainda não está disponível. Você pode continuar explorando eventos e tentar novamente mais tarde.',
                          isError: false,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_register) ...[
                        TextFormField(
                          key: const Key('auth-name'),
                          controller: _name,
                          enabled: !_busy,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          maxLength: 80,
                          decoration: const InputDecoration(
                            labelText: 'Seu nome',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) => (value ?? '').trim().length < 2
                              ? 'Informe seu nome (pelo menos 2 caracteres).'
                              : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        key: const Key('auth-email'),
                        controller: _email,
                        enabled: !_busy,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: _reset
                            ? TextInputAction.done
                            : TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                        validator: (value) =>
                            RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch((value ?? '').trim())
                            ? null
                            : 'Informe um e-mail válido.',
                        onFieldSubmitted: _reset ? (_) => _submit() : null,
                      ),
                      if (!_reset) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('auth-password'),
                          controller: _password,
                          enabled: !_busy,
                          obscureText: _hidePassword,
                          enableSuggestions: false,
                          autocorrect: false,
                          textInputAction: _register
                              ? TextInputAction.next
                              : TextInputAction.done,
                          autofillHints: [
                            _register
                                ? AutofillHints.newPassword
                                : AutofillHints.password,
                          ],
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            helperText: _register
                                ? 'Use pelo menos 8 caracteres.'
                                : null,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _hidePassword
                                  ? 'Mostrar senha'
                                  : 'Ocultar senha',
                              onPressed: _busy
                                  ? null
                                  : () => setState(
                                      () => _hidePassword = !_hidePassword,
                                    ),
                              icon: Icon(
                                _hidePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) => (value ?? '').isEmpty
                              ? 'Informe sua senha.'
                              : _register && value!.length < 8
                              ? 'Use pelo menos 8 caracteres.'
                              : null,
                          onFieldSubmitted: _register ? null : (_) => _submit(),
                        ),
                        if (_register) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const Key('auth-confirm'),
                            controller: _confirm,
                            enabled: !_busy,
                            obscureText: _hideConfirm,
                            enableSuggestions: false,
                            autocorrect: false,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            decoration: InputDecoration(
                              labelText: 'Confirmar senha',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _hideConfirm
                                    ? 'Mostrar confirmação'
                                    : 'Ocultar confirmação',
                                onPressed: _busy
                                    ? null
                                    : () => setState(
                                        () => _hideConfirm = !_hideConfirm,
                                      ),
                                icon: Icon(
                                  _hideConfirm
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) => (value ?? '').isEmpty
                                ? 'Confirme sua senha.'
                                : value != _password.text
                                ? 'As senhas não coincidem.'
                                : null,
                            onFieldSubmitted: (_) => _submit(),
                          ),
                        ] else
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _changeMode(AuthMode.reset),
                              child: const Text('Esqueci minha senha'),
                            ),
                          ),
                      ],
                      const SizedBox(height: 20),
                      if (_error != null) ...[
                        _status(_error!, isError: true),
                        const SizedBox(height: 16),
                      ],
                      if (_notice != null) ...[
                        _status(_notice!, isError: false),
                        const SizedBox(height: 16),
                      ],
                      FilledButton(
                        key: const Key('auth-submit'),
                        onPressed: _busy || !_auth.isAvailable
                            ? null
                            : () => _submit(),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                _reset
                                    ? 'Enviar link de recuperação'
                                    : _register
                                    ? 'Criar minha conta'
                                    : 'Entrar na minha conta',
                              ),
                      ),
                      if (!_reset && _auth.supportsGoogle) ...[
                        const SizedBox(height: 16),
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('ou'),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _busy || !_auth.isAvailable
                              ? null
                              : () => _submit(google: true),
                          icon: const Icon(Icons.account_circle_outlined),
                          label: const Text('Continuar com Google'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ],
                      if (_reset)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _changeMode(AuthMode.login),
                          child: const Text('Voltar para entrar'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _status(String text, {required bool isError}) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isError ? AppColors.error : AppColors.accent).withValues(
          alpha: .1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isError ? AppColors.error : AppColors.textPrimary,
          height: 1.4,
        ),
      ),
    ),
  );
}

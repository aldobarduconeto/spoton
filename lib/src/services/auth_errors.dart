import 'package:firebase_auth/firebase_auth.dart';

String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'requires-recent-login' ||
      'user-token-expired' => 'Entre novamente para continuar.',
      'invalid-email' => 'Informe um e-mail válido.',
      'invalid-credential' ||
      'wrong-password' ||
      'user-not-found' => 'E-mail ou senha incorretos.',
      'email-already-in-use' =>
        'Este e-mail já tem uma conta. Entre ou recupere sua senha.',
      'weak-password' || 'password-does-not-meet-requirements' =>
        'A senha não atende aos requisitos. Use uma senha mais forte.',
      'too-many-requests' =>
        'Muitas tentativas. Aguarde um pouco e tente novamente.',
      'network-request-failed' =>
        'Sem conexão. Verifique sua internet e tente novamente.',
      'user-disabled' =>
        'Esta conta foi desativada. Entre em contato com o suporte.',
      'operation-not-allowed' =>
        'Este método de acesso ainda não foi habilitado. Tente outra opção.',
      'not-configured' => 'O acesso à conta ainda não está disponível. Tente novamente mais tarde.',
      'popup-closed-by-user' ||
      'cancelled-popup-request' => 'O acesso com Google foi cancelado.',
      'popup-blocked' => 'Permita a janela de acesso do Google no navegador.',
      'account-exists-with-different-credential' =>
        'Entre com o método já associado a este e-mail.',
      _ => 'Não foi possível acessar sua conta. Tente novamente.',
    };
  }
  return 'Não foi possível concluir. Tente novamente.';
}

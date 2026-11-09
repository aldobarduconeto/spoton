# Spoton

Aplicativo Flutter para descobrir eventos, publicar experiências e obter ingressos.

## Funcionalidades

- Login, cadastro, recuperação de senha, Google e sessão persistida com Firebase Authentication.
- Tela de conta com edição de nome, verificação de e-mail, troca de senha com reautenticação e logout.

- Busca sem distinção de acentos, categorias, favoritos e detalhes de eventos.
- Filtros combináveis por período e gratuidade, ordenação por data, preço ou nome e limpeza dos filtros.
- Cópia dos detalhes do evento para compartilhar em outros aplicativos.
- Publicação de eventos com validação de datas, preço e checkout HTTPS.
- Emissão de ingressos gratuitos (1 a 10 por pedido) e cancelamento.
- Compra de eventos pagos pelo checkout externo do organizador.
- Interface Material 3 e ícones para Android, iOS, macOS, Windows e Web.

## Backend Firebase

Quando configurado, o aplicativo usa Firebase Authentication e Cloud Firestore:

- `events/{eventId}`: eventos públicos, com `ownerId` do organizador.
- `users/{uid}/tickets/{ticketId}`: ingressos privados, sincronizados entre dispositivos.
- `users/{uid}/favorites/{eventId}`: favoritos privados.
- `users/{uid}`: perfil da conta.

Somente usuários autenticados publicam eventos ou emitem ingressos. As regras do Firestore verificam organizador, datas, preço e dados do ingresso. Eventos pagos não podem gerar ingressos gratuitos pelo cliente. Ao sair ou trocar de conta, o app limpa imediatamente os dados privados exibidos.

Sem configuração Firebase, o app continua em modo local. Dados locais antigos permanecem no dispositivo e não são publicados nem associados automaticamente a uma conta.

O acesso por e-mail/senha usa Firebase Authentication nas plataformas configuradas, incluindo desktop. O login Google continua disponível para Android, iOS e Web. Habilite E-mail/senha no Firebase Console antes de testar contas reais.

Consulte [docs/FIREBASE.md](docs/FIREBASE.md) para configurar o projeto real, publicar as regras e usar os emuladores.

## Executar e verificar

```sh
flutter pub get
flutter run
flutter analyze
flutter test
```

Os testes em `test/` cobrem persistência local, filtros, chips, validações de autenticação e paginação com doubles. Login real, entrega de e-mails e regras do Firestore devem ser verificados no projeto configurado ou emulador.

## Pagamentos

O checkout de eventos pagos abre o site HTTPS informado pelo organizador. O pagamento e a emissão do ingresso pago acontecem nesse serviço externo. Confirmação automática de pagamento, estoque de vagas, reembolsos e validação de entrada não estão implementados. Essa integração requer um provedor de pagamento e processamento confiável de webhooks no backend; o app não armazena cartões ou segredos de pagamento.

## Android release

```sh
flutter build appbundle --release
```

Configure assinatura de produção antes de publicar. A configuração atual usa a chave de debug.

## Melhorias de descoberta

Busca sem distinção de acentos, filtros combinados de período e gratuidade, ordenação por data, preço ou nome e cópia dos detalhes do evento. Preferências locais centralizadas no StorageService, mantendo as chaves existentes. Testes em test/event_service_test.dart.


A descoberta Firebase busca eventos ativos em páginas de 40, com cursor e atualização manual. Os filtros operam nos eventos carregados. Não há leituras por tecla digitada nem escrita de perfil a cada login. Veja [configuração e limites](docs/FIREBASE.md).

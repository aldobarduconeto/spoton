import 'package:spoton/src/views/auth.dart';
import 'package:spoton/src/views/account.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:spoton/src/services/google_auth_service.dart';
import 'package:spoton/src/services/google_services.dart';
import 'package:spoton/src/services/storage_service.dart';
import 'package:spoton/src/views/widgets/colors.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  final storage = StorageService();
  bool isLoading = true;
  final Set<String> _pending = {};
  Stream<User?>? accountChanges;

  final Map<String, bool> _settings = {
    'event_notifications': false,
    'event_reminders': true,
    'event_changes': true,
    'recommended_events': true,
    'nearby_events': true,
    'favorite_events': true,
    'location_enabled': false,
  };

  @override
  void initState() {
    super.initState();
    if (GoogleServices.isInitialized)
      accountChanges = GoogleAuthService.instance.authStateChanges;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final saved = await storage.getSettings();
      if (!mounted) return;
      for (final key in _settings.keys) {
        _settings[key] = saved[key] ?? _settings[key]!;
      }
    } catch (_) {
      _showMessage('Não foi possível carregar as preferências.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _changeSetting(String name, bool value) async {
    if (_pending.contains(name) || _settings[name] == value) return;
    setState(() => _pending.add(name));
    try {
      if (name == 'event_notifications') {
        if (value) {
          if (!GoogleServices.isInitialized) {
            _showMessage('Configure o Firebase para ativar notificações push.');
            return;
          }
          if (!await GoogleServices.enableEventNotifications()) {
            _showMessage('Permissão de notificações não concedida.');
            return;
          }
        } else {
          await GoogleServices.disableEventNotifications();
        }
      }
      if (!await storage.saveSetting(name, value))
        throw StateError('Falha ao salvar');
      if (mounted) setState(() => _settings[name] = value);
    } catch (_) {
      _showMessage('Não foi possível salvar a preferência.');
    } finally {
      if (mounted) setState(() => _pending.remove(name));
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _sectionTitle(IconData icon, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
    child: Row(
      children: [
        Icon(icon, size: 19, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    ),
  );

  Widget _buildSwitch({
    required String title,
    required String subtitle,
    required IconData icon,
    required String setting,
  }) {
    return SwitchListTile(
      value: _settings[setting] ?? false,
      onChanged: isLoading || _pending.contains(setting)
          ? null
          : (value) => _changeSetting(setting, value),
      secondary: Icon(icon),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }

  Widget _buildGoogleAccount() {
    if (!GoogleServices.isInitialized) {
      return ListTile(
        leading: const CircleAvatar(child: Icon(Icons.account_circle_outlined)),
        title: const Text('Entrar ou criar conta'),
        subtitle: const Text('O acesso à conta ainda não está disponível.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AuthPage()),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: accountChanges,
      initialData: GoogleAuthService.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null) {
          return ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.account_circle_outlined),
            ),
            title: const Text('Entrar ou criar conta'),
            subtitle: const Text(
              'Entre para publicar eventos e sincronizar ingressos',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AuthPage()),
            ),
          );
        }
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user.photoURL == null
                ? null
                : NetworkImage(user.photoURL!),
            child: user.photoURL == null ? const Icon(Icons.person) : null,
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccountPage()),
          ),
          title: Text(user.displayName ?? 'Minha conta'),
          subtitle: Text(user.email ?? 'Conta conectada'),
          trailing: IconButton(
            tooltip: 'Sair da conta',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              try {
                await GoogleAuthService.instance.signOut();
                _showMessage('Você saiu da sua conta.');
              } catch (error) {
                _showMessage('Não foi possível sair: $error');
              }
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _sectionTitle(Icons.account_circle_outlined, 'Conta e sincronização'),
        _buildGoogleAccount(),
        _sectionTitle(Icons.notifications_none, 'Notificações'),
        _buildSwitch(
          title: 'Notificações de eventos',
          subtitle: 'Receber avisos pelo Firebase Cloud Messaging',
          icon: Icons.notifications_active_outlined,
          setting: 'event_notifications',
        ),
        _buildSwitch(
          title: 'Lembretes de eventos',
          subtitle: 'Ser lembrado antes de um evento começar',
          icon: Icons.alarm,
          setting: 'event_reminders',
        ),
        _buildSwitch(
          title: 'Alterações nos eventos',
          subtitle: 'Avisos sobre mudanças de horário ou local',
          icon: Icons.update,
          setting: 'event_changes',
        ),
        _buildSwitch(
          title: 'Eventos recomendados',
          subtitle: 'Sugestões de eventos que podem interessar a você',
          icon: Icons.recommend_outlined,
          setting: 'recommended_events',
        ),
        _buildSwitch(
          title: 'Eventos próximos',
          subtitle: 'Priorizar eventos perto da sua localização',
          icon: Icons.near_me_outlined,
          setting: 'nearby_events',
        ),
        _sectionTitle(Icons.settings_outlined, 'Aplicativo'),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: const Icon(Icons.info_outline),
          title: const Text('Sobre o Spoton'),
          subtitle: const Text('Central de eventos • Versão 1.0.0'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showAboutDialog(
            context: context,
            applicationName: 'Spoton',
            applicationVersion: '1.0.0',
            applicationIcon: const Icon(Icons.event_available, size: 40),
            children: const [
              Text(
                'Descubra eventos, acompanhe suas experiências e encontre o que acontece ao seu redor.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

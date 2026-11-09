import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:spoton/src/services/firebase_configuration.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
//import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

// Inicialização centralizada dos serviços Firebase/Google.
// O aplicativo continua abrindo sem configuração Firebase, mantendo os
// recursos locais ativos até que google-services.json seja adicionado.
class GoogleServices {
  GoogleServices._();
  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty)
        await Firebase.initializeApp(options: FirebaseConfiguration.options);
      _initialized = Firebase.apps.isNotEmpty;
      if (!_initialized) return;
      if (FirebaseConfiguration.useEmulators) {
        await FirebaseAuth.instance.useAuthEmulator(
          FirebaseConfiguration.emulatorHost,
          9099,
        );
        FirebaseFirestore.instance.useFirestoreEmulator(
          FirebaseConfiguration.emulatorHost,
          8080,
        );
      }
      try {
        await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
          !kDebugMode && !FirebaseConfiguration.useEmulators,
        );
      } catch (error) {
        debugPrint('Analytics indisponível nesta plataforma: $error');
      }
      final supportsCrashlytics =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);
      if (supportsCrashlytics) {
        FlutterError.onError = (details) {
          FlutterError.presentError(details);
          if (!kDebugMode)
            FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        };
        PlatformDispatcher.instance.onError = (error, stack) {
          if (!kDebugMode)
            FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      }
      /*if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          await FirebaseAppCheck.instance.activate(providerAndroid: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity);
        } catch (error) {
          // App Check é uma camada extra: uma falha de ativação não deve
          // desabilitar autenticação, Analytics ou o restante do aplicativo.
          debugPrint('App Check não foi ativado: $error');
        }
      }*/
    } on FirebaseException catch (error, stack) {
      debugPrint(
        'Firebase não configurado/indisponível: ${error.code} ${error.message}',
      );
      debugPrintStack(stackTrace: stack);
      _initialized = false;
    } catch (error, stack) {
      debugPrint('Não foi possível inicializar os serviços Google: $error');
      debugPrintStack(stackTrace: stack);
      _initialized = false;
    }
  }

  static Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    if (!_initialized) return;
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (error) {
      debugPrint('Falha no Analytics: $error');
    }
  }

  /// Solicita permissão e inscreve o dispositivo no tópico público de eventos.
  /// O envio de campanhas pode ser feito pelo Firebase Console/FCM.
  static Future<bool> enableEventNotifications() async {
    if (!_initialized) return false;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final allowed =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (allowed) {
        await messaging.subscribeToTopic('spoton_events');
        await logEvent('event_notifications_enabled');
      }
      return allowed;
    } catch (error) {
      debugPrint('Não foi possível ativar notificações push: $error');
      return false;
    }
  }

  static Future<void> disableEventNotifications() async {
    if (!_initialized) return;
    try {
      await FirebaseMessaging.instance.unsubscribeFromTopic('spoton_events');
    } catch (error) {
      debugPrint('Não foi possível desativar notificações push: $error');
    }
  }
}

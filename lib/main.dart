import 'package:spoton/src/services/firebase_event_backend.dart';
import 'package:spoton/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:spoton/src/services/event_service.dart';
import 'package:spoton/src/services/location_service.dart';
import 'package:spoton/src/services/google_services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Força orientação apenas retrato
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await GoogleServices.initialize();
  final eventService = EventService(
    backend: GoogleServices.isInitialized ? FirebaseEventBackend() : null,
  );
  await eventService.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<EventService>.value(value: eventService),
        ChangeNotifierProvider<LocationService>(
          create: (_) => LocationService(),
        ),
      ],
      child: const App(),
    ),
  );
}

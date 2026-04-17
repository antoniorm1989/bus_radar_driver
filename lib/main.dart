import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';
import 'services/session_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/service_screen.dart';
import 'widgets/professional_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FlutterForegroundTask.initCommunicationPort();
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'bus_radar_tracking',
      channelName: 'Rastreo de unidad',
      channelDescription:
          'Mantiene el envio de ubicacion de la unidad mientras esta en ruta.',
      channelImportance: NotificationChannelImportance.DEFAULT,
      priority: NotificationPriority.DEFAULT,
      playSound: false,
      enableVibration: false,
      showBadge: false,
      onlyAlertOnce: true,
      visibility: NotificationVisibility.VISIBILITY_PUBLIC,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(7000),
      autoRunOnBoot: true,
      autoRunOnMyPackageReplaced: true,
      allowWakeLock: true,
      allowWifiLock: true,
      allowAutoRestart: true,
    ),
  );

  runApp(const BusRadarDriverApp());
}

class BusRadarDriverApp extends StatelessWidget {
  const BusRadarDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SessionProvider(),
      child: MaterialApp(
        title: 'Bus Radar Driver',
        theme: professionalTheme,
        initialRoute: '/',
        routes: {
          '/': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/service': (context) => const ServiceScreen(),
        },
      ),
    );
  }
}
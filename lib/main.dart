
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'services/session_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/service_screen.dart';
import 'widgets/professional_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final Logger _logger = Logger();
  _logger.i('Iniciando inicialización de Firebase...');
  try {
    await Firebase.initializeApp();
    _logger.i('Firebase inicializado correctamente');
  } catch (e, st) {
    _logger.e('Error al inicializar Firebase: $e\n$st');
  }
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

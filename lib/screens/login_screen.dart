import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';
import '../services/session_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      final sessionProvider =
          Provider.of<SessionProvider>(context, listen: false);

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await sessionProvider.initializeSession();

        if (sessionProvider.error == null && mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final sessionProvider = context.watch<SessionProvider>();
    final bool isAndroid = Platform.isAndroid;
    final bool isIOS = Platform.isIOS;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: sessionProvider.isLoading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Ícono de unidad
                    Padding(
                      padding: const EdgeInsets.only(bottom: 32.0),
                      child: Icon(
                        Icons.directions_car_filled_rounded,
                        size: 80,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      'Unidad',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Inicia sesión para comenzar a operar esta unidad',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.black54, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    if (sessionProvider.error != null)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          sessionProvider.error!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (isAndroid)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.login),
                          label: const Text('Iniciar sesión con Google'),
                          onPressed: () async {
                            final user =
                                await authService.signInWithGoogle();
                            if (user != null) {
                              await sessionProvider.initializeSession();
                              if (sessionProvider.error == null) {
                                if (!mounted) return;
                                Navigator.pushReplacementNamed(
                                    context, '/home');
                              }
                            } else {
                              sessionProvider.error =
                                  'No se pudo iniciar sesión';
                              sessionProvider.notifyListeners();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                              minimumSize: const Size(220, 56)),
                        ),
                      ),
                    if (isIOS)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.apple),
                          label:
                              const Text('Iniciar sesión con Apple'),
                          onPressed: () async {
                            final user =
                                await authService.signInWithApple();
                            if (user != null) {
                              await sessionProvider.initializeSession();
                              if (sessionProvider.error == null) {
                                if (!mounted) return;
                                Navigator.pushReplacementNamed(
                                    context, '/home');
                              }
                            } else {
                              sessionProvider.error =
                                  'No se pudo iniciar sesión';
                              sessionProvider.notifyListeners();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                              minimumSize: const Size(220, 56)),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
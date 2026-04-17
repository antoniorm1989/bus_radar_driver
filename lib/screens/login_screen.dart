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
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -90,
            left: -70,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 48,
            right: -34,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                color: const Color(0xFFDCE5F2).withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 180,
            left: -28,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 132,
                          height: 132,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: const Color(0xFFDCE3ED)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 26,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.asset(
                                'assets/branding/logo_oficial.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Bus Radar Driver',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Acceso de operador',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF607085),
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                          child: sessionProvider.isLoading
                              ? Column(
                                  children: [
                                    Container(
                                      width: 88,
                                      height: 88,
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(child: CircularProgressIndicator()),
                                    ),
                                    const SizedBox(height: 22),
                                    Text(
                                      'Verificando credenciales',
                                      style: theme.textTheme.titleMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Espera un momento mientras restauramos la sesión del operador.',
                                      style: theme.textTheme.bodyMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFD),
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 34,
                                            height: 34,
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Icon(
                                              Icons.badge_outlined,
                                              color: theme.colorScheme.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Inicio de sesión',
                                                  style: theme.textTheme.titleMedium,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Acceso exclusivo para operadores autorizados. Se utilizará para transmitir la ubicación del vehículo',
                                                  style: theme.textTheme.bodyMedium?.copyWith(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (sessionProvider.error != null) ...[
                                      const SizedBox(height: 18),
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFDEEEE),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: const Color(0xFFF2CACA)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.error_outline_rounded, color: Color(0xFFB3261E)),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                sessionProvider.error!,
                                                style: theme.textTheme.bodyMedium?.copyWith(
                                                  color: const Color(0xFF8B1E18),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 24),
                                    if (isAndroid)
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.login_rounded),
                                          label: const Text('Iniciar sesión con Google'),
                                          onPressed: () async {
                                            final user = await authService.signInWithGoogle();
                                            if (user != null) {
                                              await sessionProvider.initializeSession();
                                              if (sessionProvider.error == null) {
                                                if (!mounted) return;
                                                Navigator.pushReplacementNamed(context, '/home');
                                              }
                                            } else {
                                              sessionProvider.error = 'No se pudo iniciar sesión';
                                              sessionProvider.notifyListeners();
                                            }
                                          },
                                        ),
                                      ),
                                    if (isIOS)
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.apple),
                                          label: const Text('Iniciar sesión con Apple'),
                                          onPressed: () async {
                                            final user = await authService.signInWithApple();
                                            if (user != null) {
                                              await sessionProvider.initializeSession();
                                              if (sessionProvider.error == null) {
                                                if (!mounted) return;
                                                Navigator.pushReplacementNamed(context, '/home');
                                              }
                                            } else {
                                              sessionProvider.error = 'No se pudo iniciar sesión';
                                              sessionProvider.notifyListeners();
                                            }
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
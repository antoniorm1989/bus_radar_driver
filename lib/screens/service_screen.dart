import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/session_provider.dart';
import '../widgets/status_indicator.dart';
import '../widgets/big_button.dart';

class ServiceScreen extends StatefulWidget {
  const ServiceScreen({super.key});

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  @override
  Widget build(BuildContext context) {
    final sessionProvider = Provider.of<SessionProvider>(context);
    final driver = sessionProvider.driver;
    final bus = sessionProvider.bus;
    final route = sessionProvider.route;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Servicio Activo')),
      body: sessionProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(28),
                        bottomRight: Radius.circular(28),
                      ),
                    ),
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Seguimiento del servicio',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Monitorea la transmisión actual y administra el estado del recorrido.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              StatusIndicator(
                                isActive: sessionProvider.isActive,
                                isSendingLocation: sessionProvider.isSendingLocation,
                                gpsError: sessionProvider.gpsError,
                                connectionError: sessionProvider.connectionError,
                                trackingStatus: sessionProvider.trackingStatus,
                                trackingError: sessionProvider.trackingError,
                                trackingMessage: sessionProvider.trackingMessage,
                                lastSentAt: sessionProvider.lastSentAt,
                                lastTrackingAt: sessionProvider.lastTrackingAt,
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F9FC),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFE3E8F0)),
                                ),
                                child: Column(
                                  children: [
                                    if (driver != null)
                                      _ServiceInfoRow(
                                        icon: Icons.person_outline_rounded,
                                        label: 'Chofer',
                                        value: driver.name,
                                      ),
                                    if (bus != null)
                                      _ServiceInfoRow(
                                        icon: Icons.directions_bus_rounded,
                                        label: 'Unidad',
                                        value: bus.displayName,
                                      ),
                                    if (route != null)
                                      _ServiceInfoRow(
                                        icon: Icons.alt_route_rounded,
                                        label: 'Ruta',
                                        value: route.name,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (sessionProvider.error != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDEEEE),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFF2CACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFB3261E)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  sessionProvider.error!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF8B1E18),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (sessionProvider.error != null) const SizedBox(height: 18),
                      sessionProvider.isActive
                          ? BigButton(
                              text: 'Detener servicio',
                              color: Colors.red,
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Confirmar'),
                                    content: const Text('¿Seguro que deseas detener el servicio?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Detener'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await sessionProvider.stopService();
                                  if (sessionProvider.error == null) {
                                    Navigator.pushReplacementNamed(context, '/home');
                                  }
                                }
                              },
                            )
                          : BigButton(
                              text: 'Iniciar servicio',
                              color: const Color(0xFF1F8B4C),
                              onPressed: () async {
                                await sessionProvider.startService();
                                if (sessionProvider.error == null) {
                                  // Servicio iniciado correctamente
                                }
                              },
                            ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ServiceInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ServiceInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6A7587),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

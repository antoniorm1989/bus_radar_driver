import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../services/session_provider.dart';
import '../widgets/status_indicator.dart';
import '../services/auth_service.dart';
import 'package:geolocator/geolocator.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessionProvider = Provider.of<SessionProvider>(context);
    final driver = sessionProvider.driver;
    final bus = sessionProvider.bus;
    final route = sessionProvider.route;
    final canToggleService =
        driver != null && bus != null && route != null;

    Future<void> handleServiceToggle() async {
      if (!canToggleService) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verifica chofer, unidad y ruta asignados para continuar.'),
          ),
        );
        return;
      }

      if (sessionProvider.isActive) {
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
          if (!context.mounted) return;
          if (sessionProvider.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(sessionProvider.error!)),
            );
          }
        }
      } else {
        await sessionProvider.startService();
        if (!context.mounted) return;
        if (sessionProvider.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(sessionProvider.error!)),
          );
        } else if (!sessionProvider.isActive) {
          final message = sessionProvider.trackingError ??
              'No se pudo iniciar el servicio. Revisa GPS, permisos y conexión.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Bus Radar Driver')),
      drawer: _OperationsDrawer(
        driverName: driver?.name,
        busId: bus?.id,
        routeName: route?.name,
        isServiceActive: sessionProvider.isActive,
        onSignOut: () async {
          Navigator.pop(context);
          await sessionProvider.stopService();
          await AuthService().signOut();
          if (!context.mounted) return;
          Navigator.pushReplacementNamed(context, '/');
        },
      ),
      body: sessionProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (sessionProvider.error != null) ...[
                            _ErrorBanner(message: sessionProvider.error!),
                            const SizedBox(height: 12),
                          ],
                          _ProfessionalInfoCard(
                            isActive: sessionProvider.isActive,
                            speed: sessionProvider.speed,
                            driverName: driver?.name,
                            busId: bus?.id,
                            routeName: route?.name,
                          ),
                          Expanded(
                            child: Center(
                              child: _ControlPanel(
                                isActive: sessionProvider.isActive,
                                enabled: canToggleService,
                                onPressed: handleServiceToggle,
                              ),
                            ),
                          ),
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
                          if (sessionProvider.gpsError || sessionProvider.connectionError) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                if (sessionProvider.gpsError)
                                  OutlinedButton.icon(
                                    onPressed: () => Geolocator.openLocationSettings(),
                                    icon: const Icon(Icons.gps_fixed_rounded),
                                    label: const Text('Activar GPS'),
                                  ),
                                if (sessionProvider.connectionError)
                                  OutlinedButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(Icons.network_check_rounded),
                                    label: const Text('Revisar conexión'),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ProfessionalInfoCard extends StatefulWidget {
  final bool isActive;
  final double? speed;
  final String? driverName;
  final String? busId;
  final String? routeName;
  const _ProfessionalInfoCard({
    required this.isActive,
    required this.speed,
    required this.driverName,
    required this.busId,
    required this.routeName,
  });
  @override
  State<_ProfessionalInfoCard> createState() => _ProfessionalInfoCardState();
}

class _ProfessionalInfoCardState extends State<_ProfessionalInfoCard> {
  late DateTime _now;
  Timer? _timer;
  DateTime? _serviceStart;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _now = DateTime.now();
      });
    });
    if (widget.isActive) {
      _serviceStart = DateTime.now();
    }
  }

  @override
  void didUpdateWidget(covariant _ProfessionalInfoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _serviceStart = DateTime.now();
    }
    if (!widget.isActive && oldWidget.isActive) {
      _serviceStart = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final h = twoDigits(d.inHours);
    final m = twoDigits(d.inMinutes.remainder(60));
    final s = twoDigits(d.inSeconds.remainder(60));
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    final duration = widget.isActive && _serviceStart != null ? _now.difference(_serviceStart!) : null;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            if (widget.driverName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ClassicInfoLine(
                  icon: Icons.person,
                  value: widget.driverName!,
                  strong: false,
                ),
              ),
            if (widget.busId != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ClassicInfoLine(
                  icon: Icons.directions_bus,
                  value: 'Camión: ${widget.busId!}',
                ),
              ),
            if (widget.routeName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _ClassicInfoLine(
                  icon: Icons.alt_route,
                  value: 'Ruta: ${widget.routeName!}',
                ),
              ),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.speed_rounded, color: const Color(0xFF607D8B), size: 36),
                  const SizedBox(width: 12),
                  Text(
                    widget.speed != null ? '${widget.speed!.toStringAsFixed(1)} km/h' : '-- km/h',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ClassicMiniMetric(
                    icon: Icons.access_time_rounded,
                    value: timeStr,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ClassicMiniMetric(
                    icon: Icons.timer_outlined,
                    value: duration != null ? _formatDuration(duration) : '--:--:--',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OperationsDrawer extends StatelessWidget {
  final String? driverName;
  final String? busId;
  final String? routeName;
  final bool isServiceActive;
  final Future<void> Function() onSignOut;

  const _OperationsDrawer({
    required this.driverName,
    required this.busId,
    required this.routeName,
    required this.isServiceActive,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName ?? 'Usuario',
                      style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Panel asignado a la operación de la unidad.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (busId != null)
                          _HeaderChip(icon: Icons.directions_bus_rounded, label: 'Unidad $busId'),
                        if (routeName != null)
                          _HeaderChip(icon: Icons.alt_route_rounded, label: routeName!),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Cerrar sesión'),
                onPressed: onSignOut,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerDetailTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DrawerDetailTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6A7587),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  final bool isActive;
  final bool enabled;
  final Future<void> Function() onPressed;

  const _ControlPanel({
    required this.isActive,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = isActive ? const Color(0xFF67BA6A) : theme.colorScheme.primary;
    final labelColor = isActive ? const Color(0xFF2F8F46) : const Color(0xFF64748B);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: enabled ? 1 : 0.55,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: buttonColor,
                boxShadow: [
                  BoxShadow(
                    color: buttonColor.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.power_settings_new_rounded,
                  size: 92,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isActive ? 'Servicio encendido' : 'Servicio apagado',
          style: theme.textTheme.titleMedium?.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ClassicInfoLine extends StatelessWidget {
  final IconData icon;
  final String value;
  final bool strong;

  const _ClassicInfoLine({
    required this.icon,
    required this.value,
    this.strong = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, color: const Color(0xFF607D8B), size: 34),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: 16,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ClassicMiniMetric extends StatelessWidget {
  final IconData icon;
  final String value;

  const _ClassicMiniMetric({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: const Color(0xFF607D8B), size: 32),
        const SizedBox(width: 8),
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool center;

  const _SectionLabel({
    required this.title,
    required this.subtitle,
    this.center = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment:
          center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium,
          textAlign: center ? TextAlign.center : TextAlign.start,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium,
          textAlign: center ? TextAlign.center : TextAlign.start,
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF8B1E18),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoLine({
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
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
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

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(height: 10),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6A7587),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
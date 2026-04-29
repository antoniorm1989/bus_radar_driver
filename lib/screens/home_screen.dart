import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../services/session_provider.dart';
import '../widgets/status_indicator.dart';
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
    final hasPermissionIssue =
      sessionProvider.trackingStatus == 'permission_required';

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
      body: sessionProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
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
                            busId: bus?.displayName,
                            routeName: route?.name,
                            todayRouteTimes: sessionProvider.routeTimesToday,
                          ),
                          Expanded(
                            child: Center(
                              child: _ControlPanel(
                                isActive: sessionProvider.isActive,
                                enabled: canToggleService,
                                currentRouteStartedAt:
                                    sessionProvider.currentRouteStartedAt,
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
                          if (sessionProvider.gpsError ||
                              sessionProvider.connectionError ||
                              hasPermissionIssue) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                if (hasPermissionIssue)
                                  OutlinedButton.icon(
                                    onPressed: () => Geolocator.openAppSettings(),
                                    icon: const Icon(Icons.settings_rounded),
                                    label: const Text('Permisos de ubicacion'),
                                  ),
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
  final List<RouteTimeEntry> todayRouteTimes;

  const _ProfessionalInfoCard({
    required this.isActive,
    required this.speed,
    required this.driverName,
    required this.busId,
    required this.routeName,
    required this.todayRouteTimes,
  });

  @override
  State<_ProfessionalInfoCard> createState() => _ProfessionalInfoCardState();
}

class _ProfessionalInfoCardState extends State<_ProfessionalInfoCard> {
  String _formatClock(DateTime value) {
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _formatCompactDuration(Duration duration) {
    final safe = duration.isNegative ? Duration.zero : duration;
    final totalMinutes = safe.inMinutes;

    if (totalMinutes < 60) {
      return '${totalMinutes}m';
    }

    final totalHours = totalMinutes ~/ 60;
    final remainingMinutes = totalMinutes % 60;
    if (totalHours < 24) {
      if (remainingMinutes == 0) {
        return '${totalHours}h';
      }
      return '${totalHours}h ${remainingMinutes}m';
    }

    final days = totalHours ~/ 24;
    final remainingHours = totalHours % 24;
    if (remainingHours == 0) {
      return '${days}d';
    }
    return '${days}d ${remainingHours}h';
  }

  String _historyDurationLabel(RouteTimeEntry run) {
    final storedSeconds = run.durationSec;
    if (storedSeconds != null) {
      return _formatCompactDuration(Duration(seconds: storedSeconds));
    }

    final endedAt = run.endedAt;
    if (endedAt == null) {
      return '--';
    }

    return _formatCompactDuration(endedAt.difference(run.startedAt));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final speedLabel = widget.speed != null
        ? '${widget.speed!.toStringAsFixed(1)} km/h'
        : '-- km/h';

    final completedRuns = widget.todayRouteTimes
        .where((run) => run.endedAt != null)
        .toList(growable: false);
    final visibleRuns = completedRuns.length > 4
      ? completedRuns.sublist(completedRuns.length - 4)
        : completedRuns;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE3E8EF)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.driverName != null)
              _PremiumInfoLine(
                icon: Icons.person_rounded,
                label: 'Chofer',
                value: widget.driverName!,
              ),
            if (widget.busId != null)
              _PremiumInfoLine(
                icon: Icons.directions_bus_rounded,
                label: 'Unidad',
                value: widget.busId!,
              ),
            if (widget.routeName != null)
              _PremiumInfoLine(
                icon: Icons.alt_route_rounded,
                label: 'Ruta',
                value: widget.routeName!,
              ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F8FC),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.speed_rounded,
                    color: Color(0xFF5C7286),
                    size: 21,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    speedLabel,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E2F43),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                const Icon(
                  Icons.today_rounded,
                  size: 16,
                  color: Color(0xFF4A607A),
                ),
                const SizedBox(width: 5),
                Text(
                  'Hoy',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF3B4F67),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${completedRuns.length} tramos',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7C90),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (visibleRuns.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sin tramos finalizados hoy.',
                      style: TextStyle(
                        color: Color(0xFF6E8094),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Solo se registra un tramo si dura mas de 5 min.',
                      style: TextStyle(
                        color: Color(0xFF8A99AB),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: [
                  for (final run in visibleRuns)
                    _RouteHistoryRow(
                      rangeLabel:
                          '${_formatClock(run.startedAt)} a ${_formatClock(run.endedAt!)}',
                      durationLabel: _historyDurationLabel(run),
                    ),
                  if (completedRuns.length > visibleRuns.length)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+${completedRuns.length - visibleRuns.length} tramos mas',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6B7C90),
                          fontWeight: FontWeight.w600,
                        ),
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

class _PremiumInfoLine extends StatelessWidget {
  const _PremiumInfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5FB),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF607A92)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5F7186),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: const Color(0xFF1F2E41),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteHistoryRow extends StatelessWidget {
  const _RouteHistoryRow({
    required this.rangeLabel,
    required this.durationLabel,
  });

  final String rangeLabel;
  final String durationLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE1E8F3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              rangeLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF30465F),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            durationLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF153D70),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlPanel extends StatefulWidget {
  final bool isActive;
  final bool enabled;
  final DateTime? currentRouteStartedAt;
  final Future<void> Function() onPressed;

  const _ControlPanel({
    required this.isActive,
    required this.enabled,
    required this.currentRouteStartedAt,
    required this.onPressed,
  });

  @override
  State<_ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<_ControlPanel> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant _ControlPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  void _syncTicker() {
    final shouldTick = widget.isActive && widget.currentRouteStartedAt != null;
    if (shouldTick) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _now = DateTime.now();
        });
      });
      return;
    }

    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String? _runningCounterLabel() {
    final startedAt = widget.currentRouteStartedAt;
    if (!widget.isActive || startedAt == null) {
      return null;
    }

    final diff = _now.difference(startedAt);
    final safe = diff.isNegative ? Duration.zero : diff;

    final days = safe.inDays;
    final hours = safe.inHours.remainder(24);
    final minutes = safe.inMinutes.remainder(60);
    final seconds = safe.inSeconds.remainder(60);

    final parts = <String>[];
    if (days > 0) {
      parts.add('${days}d');
    }
    if (hours > 0) {
      parts.add('${hours}h');
    }
    if (minutes > 0) {
      parts.add('${minutes}m');
    }
    if (seconds > 0 || parts.isEmpty) {
      parts.add('${seconds}s');
    }

    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor =
        widget.isActive ? const Color(0xFF67BA6A) : theme.colorScheme.primary;
    final labelColor =
        widget.isActive ? const Color(0xFF2F8F46) : const Color(0xFF64748B);
    final runningCounterLabel = _runningCounterLabel();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 220.0;
        final availableWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 260.0;

        final diameterByHeight =
            (availableHeight - 30).clamp(82.0, 160.0).toDouble();
        final diameterByWidth =
            (availableWidth - 24).clamp(82.0, 160.0).toDouble();
        final diameter = math.min(diameterByHeight, diameterByWidth);
        final iconSize = (diameter * 0.42).clamp(34.0, 74.0).toDouble();
        final innerRingSize = (diameter * 0.74).clamp(68.0, 122.0).toDouble();
        final verticalGap = diameter < 130 ? 4.0 : 8.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: widget.onPressed,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: widget.enabled ? 1 : 0.55,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  width: diameter,
                  height: diameter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: buttonColor,
                    boxShadow: [
                      BoxShadow(
                        color: buttonColor.withValues(alpha: 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: runningCounterLabel != null
                      ? Center(
                          child: Container(
                            width: innerRingSize,
                            height: innerRingSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.88),
                                width: 2,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.timer_outlined,
                                    size: 29,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    child: Text(
                                      runningCounterLabel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.power_settings_new_rounded,
                            size: iconSize,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
            SizedBox(height: verticalGap),
            Text(
              widget.isActive ? 'Servicio encendido' : 'Servicio apagado',
              style: theme.textTheme.titleMedium?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w700,
                fontSize: diameter < 130 ? 15 : 16,
              ),
            ),
          ],
        );
      },
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
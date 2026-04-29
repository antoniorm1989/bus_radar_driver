import 'package:flutter/material.dart';

class StatusIndicator extends StatefulWidget {
  final bool isActive;
  final bool isSendingLocation;
  final bool gpsError;
  final bool connectionError;
  final String trackingStatus;
  final String? trackingError;
  final String? trackingMessage;
  final DateTime? lastSentAt;
  final DateTime? lastTrackingAt;

  const StatusIndicator({
    super.key,
    required this.isActive,
    required this.isSendingLocation,
    this.gpsError = false,
    this.connectionError = false,
    required this.trackingStatus,
    this.trackingError,
    this.trackingMessage,
    this.lastSentAt,
    this.lastTrackingAt,
  });

  @override
  State<StatusIndicator> createState() => _StatusIndicatorState();
}

class _StatusIndicatorState extends State<StatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blinkController;
  late final Animation<double> _blinkAnimation;

  bool get _isSending =>
      widget.isActive && widget.isSendingLocation;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _blinkAnimation = Tween<double>(begin: 0.25, end: 1).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
    _syncBlink();
  }

  @override
  void didUpdateWidget(covariant StatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasSending = oldWidget.isActive && oldWidget.isSendingLocation;
    if (_isSending != wasSending) {
      _syncBlink();
    }
  }

  void _syncBlink() {
    if (_isSending) {
      _blinkController.repeat(reverse: true);
    } else {
      _blinkController.stop();
      _blinkController.value = 1;
    }
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  String _formatAge(DateTime? dateTime) {
    if (dateTime == null) return 'sin registro reciente';

    final seconds = DateTime.now().difference(dateTime).inSeconds;
    if (seconds < 60) return 'hace ${seconds.clamp(0, 59)}s';

    final minutes = seconds ~/ 60;
    return 'hace ${minutes}m';
  }

  _IndicatorData _resolveIndicator() {
    if (!widget.isActive) {
      return const _IndicatorData(
        color: Color(0xFF6B7280),
        title: 'Servicio detenido',
        subtitle: 'Activa el servicio para iniciar el rastreo.',
      );
    }

    if (widget.gpsError || widget.trackingStatus == 'gps_off') {
      return const _IndicatorData(
        color: Color(0xFFD97706),
        title: 'GPS desactivado',
        subtitle: 'Activa el GPS para enviar ubicación.',
      );
    }

    if (widget.connectionError || widget.trackingStatus == 'network_error') {
      return const _IndicatorData(
        color: Color(0xFFB91C1C),
        title: 'Sin conexión',
        subtitle: 'No hay red disponible para transmitir ubicación.',
      );
    }

    final trackingAgeSeconds = widget.lastTrackingAt != null
        ? DateTime.now().difference(widget.lastTrackingAt!).inSeconds
        : null;

    if (trackingAgeSeconds != null && trackingAgeSeconds > 180) {
      return _IndicatorData(
        color: const Color(0xFFB91C1C),
        title: 'Desconectado',
        subtitle: 'Más de 3 minutos sin actualización (${_formatAge(widget.lastTrackingAt)}).',
      );
    }

    if (trackingAgeSeconds != null && trackingAgeSeconds > 60) {
      return _IndicatorData(
        color: const Color(0xFFD97706),
        title: 'Detenido',
        subtitle: 'Más de 1 minuto sin actualización (${_formatAge(widget.lastTrackingAt)}).',
      );
    }

    if (_isSending) {
      return _IndicatorData(
        color: const Color(0xFF1F8B4C),
        title: 'Enviando ubicación',
        subtitle: 'Último envío ${_formatAge(widget.lastSentAt)}.',
      );
    }

    if (widget.trackingStatus == 'idle') {
      return const _IndicatorData(
        color: Color(0xFF475569),
        title: 'Servicio activo sin movimiento',
        subtitle: 'No se envía ubicación cuando la unidad está detenida.',
      );
    }

    if (widget.trackingError != null) {
      return _IndicatorData(
        color: const Color(0xFFB91C1C),
        title: 'Revisión requerida',
        subtitle: widget.trackingError!,
      );
    }

    return _IndicatorData(
      color: const Color(0xFF475569),
      title: 'Verificando estado',
      subtitle: 'Última actualización ${_formatAge(widget.lastTrackingAt)}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicator = _resolveIndicator();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Icon(
                  _isSending ? Icons.wifi_tethering_rounded : Icons.pause_circle_filled,
                  size: 19,
                  color: const Color(0xFF546E7A),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  indicator.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF334155),
                    fontSize: 15,
                  ),
                ),
              ),
              FadeTransition(
                opacity: _isSending ? _blinkAnimation : const AlwaysStoppedAnimation(1),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: indicator.color,
                    shape: BoxShape.circle,
                    boxShadow: _isSending
                        ? [
                            BoxShadow(
                              color: indicator.color.withValues(alpha: 0.45),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            indicator.subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475569),
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _IndicatorData {
  final Color color;
  final String title;
  final String subtitle;

  const _IndicatorData({
    required this.color,
    required this.title,
    required this.subtitle,
  });
}

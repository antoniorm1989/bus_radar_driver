import 'package:flutter/material.dart';

class StatusIndicator extends StatelessWidget {
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

  String _formatAge(DateTime? dateTime) {
    if (dateTime == null) return 'sin registro reciente';

    final seconds = DateTime.now().difference(dateTime).inSeconds;
    if (seconds < 60) return 'hace ${seconds.clamp(0, 59)}s';

    final minutes = seconds ~/ 60;
    return 'hace ${minutes}m';
  }

  _StatusVisual _resolveVisual() {
    if (!isActive) {
      return _StatusVisual(
        color: Colors.grey.shade700,
        icon: Icons.power_settings_new_rounded,
        title: 'Servicio apagado',
        subtitle: 'Presiona el boton para iniciar la ruta.',
      );
    }

    if (gpsError || trackingStatus == 'gps_off') {
      return _StatusVisual(
        color: Colors.orange.shade800,
        icon: Icons.gps_off_rounded,
        title: 'GPS apagado',
        subtitle: 'Activa GPS para poder enviar ubicacion.',
      );
    }

    if (trackingStatus == 'permission_required') {
      return _StatusVisual(
        color: Colors.deepOrange.shade700,
        icon: Icons.lock_outline_rounded,
        title: 'Falta permiso de ubicacion',
        subtitle: trackingMessage ?? 'Se requiere permiso en segundo plano.',
      );
    }

    if (connectionError || trackingStatus == 'network_error') {
      return _StatusVisual(
        color: Colors.red.shade700,
        icon: Icons.wifi_off_rounded,
        title: 'Sin internet',
        subtitle: 'No se puede enviar ubicacion en este momento.',
      );
    }

    if (isSendingLocation && trackingStatus == 'sending') {
      return _StatusVisual(
        color: Colors.green.shade700,
        icon: Icons.near_me_rounded,
        title: 'Ubicacion enviandose',
        subtitle: 'Ultimo envio ${_formatAge(lastSentAt)}.',
      );
    }

    if (trackingStatus == 'idle') {
      return _StatusVisual(
        color: Colors.blueGrey.shade700,
        icon: Icons.pause_circle_filled_rounded,
        title: 'Servicio activo sin movimiento',
        subtitle: 'No se envia ubicacion cuando la unidad esta detenida.',
      );
    }

    if (trackingError != null) {
      return _StatusVisual(
        color: Colors.red.shade700,
        icon: Icons.error_outline_rounded,
        title: 'Atencion requerida',
        subtitle: trackingError!,
      );
    }

    return _StatusVisual(
      color: Colors.amber.shade800,
      icon: Icons.sync_problem_rounded,
      title: 'Verificando rastreo',
      subtitle: 'Ultima senal ${_formatAge(lastTrackingAt)}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final visual = _resolveVisual();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: visual.color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: visual.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(visual.icon, color: visual.color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visual.title,
                  style: TextStyle(
                    color: visual.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  visual.subtitle,
                  style: TextStyle(
                    color: visual.color.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusVisual {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;

  const _StatusVisual({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

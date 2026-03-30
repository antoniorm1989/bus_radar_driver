import 'package:flutter/material.dart';

class StatusIndicator extends StatelessWidget {
  final bool isActive;
  final bool gpsError;
  final bool connectionError;

  const StatusIndicator({
    super.key,
    required this.isActive,
    this.gpsError = false,
    this.connectionError = false,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    IconData icon;
    if (gpsError) {
      color = Colors.orange.shade700;
      text = 'GPS no disponible';
      icon = Icons.gps_off_rounded;
    } else if (connectionError) {
      color = Colors.red.shade700;
      text = 'Sin conexión';
      icon = Icons.wifi_off_rounded;
    } else if (isActive) {
      color = Colors.green.shade700;
      text = 'Servicio activo';
      icon = Icons.check_circle_rounded;
    } else {
      color = Colors.red.shade700;
      text = 'Servicio detenido';
      icon = Icons.cancel_rounded;
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }
}

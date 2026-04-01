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

    return Scaffold(
      appBar: AppBar(title: const Text('Unidad')),
      drawer: Drawer(
        child: Container(
          color: Colors.white,
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 36),
                CircleAvatar(
                  radius: 38,
                  backgroundColor: const Color(0xFFF5F6FA),
                  child: const Icon(Icons.person, color: Color(0xFF1A237E), size: 44),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    driver?.name ?? 'Usuario',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    bus != null ? 'Unidad: ${bus.id}' : '',
                    style: const TextStyle(color: Color(0xFF6B7280)),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('Cerrar sesión'),
                      onPressed: () async {
                        Navigator.pop(context);
                        await sessionProvider.stopService();
                        await AuthService().signOut();
                        if (!context.mounted) return;
                        Navigator.pushReplacementNamed(context, '/');
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: sessionProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (sessionProvider.error != null)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          sessionProvider.error!,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),

                    _ProfessionalInfoCard(
                      isActive: sessionProvider.isActive,
                      speed: sessionProvider.speed,
                      driverName: driver?.name,
                      busId: bus?.id,
                      routeName: route?.name,
                    ),

                    const SizedBox(height: 36),

                    GestureDetector(
                      onTap: (sessionProvider.error == null && driver != null && bus != null && route != null)
                          ? () async {
                              if (sessionProvider.isActive) {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Confirmar'),
                                    content: const Text('¿Seguro que deseas detener el servicio?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Detener')),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await sessionProvider.stopService();
                                }
                              } else {
                                await sessionProvider.startService();
                              }
                            }
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: sessionProvider.isActive ? Colors.green.shade400 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(60),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.power_settings_new,
                            color: sessionProvider.isActive ? Colors.white : Colors.grey.shade600,
                            size: 64,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

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

                    const SizedBox(height: 16),

                    if (sessionProvider.gpsError)
                      ElevatedButton(
                        onPressed: () => Geolocator.openLocationSettings(),
                        child: const Text('Activar GPS'),
                      ),

                    if (sessionProvider.connectionError)
                      ElevatedButton(
                        onPressed: () {},
                        child: const Text('Revisar conexión'),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

// 🔥 Card profesional de estado y datos
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
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Estado del servicio con fondo suave y borde
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: widget.isActive ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: widget.isActive ? Colors.green.shade200 : Colors.red.shade200,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: widget.isActive ? Colors.green.shade700 : Colors.red.shade700,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.isActive ? 'Servicio activo' : 'Servicio detenido',
                    style: TextStyle(
                      color: widget.isActive ? Colors.green.shade700 : Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Datos principales con iconos alineados
            if (widget.driverName != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.blueGrey, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(widget.driverName!, style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ],
                ),
              ),
            if (widget.busId != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.directions_bus, color: Colors.blueGrey, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Camión: ${widget.busId}', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            if (widget.routeName != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.alt_route, color: Colors.blueGrey, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Ruta: ${widget.routeName}', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 18),
            // Velocidad
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.speed, color: Colors.blueGrey.shade400),
                const SizedBox(width: 8),
                Text(
                  widget.speed != null ? '${widget.speed!.toStringAsFixed(1)} km/h' : '-- km/h',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Hora actual y tiempo en servicio
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.access_time, color: Colors.blueGrey, size: 20),
                const SizedBox(width: 8),
                Text(timeStr, style: Theme.of(context).textTheme.bodyLarge),
                if (duration != null) ...[
                  const SizedBox(width: 18),
                  const Icon(Icons.timer, color: Colors.blueGrey, size: 20),
                  const SizedBox(width: 8),
                  Text(_formatDuration(duration), style: Theme.of(context).textTheme.bodyLarge),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
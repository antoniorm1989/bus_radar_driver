import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/session_provider.dart';
import '../widgets/status_indicator.dart';
import '../widgets/big_button.dart';

class ServiceScreen extends StatefulWidget {
  const ServiceScreen({Key? key}) : super(key: key);

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
    return Scaffold(
      appBar: AppBar(title: const Text('Servicio Activo')),
      body: sessionProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        child: Column(
                          children: [
                            StatusIndicator(
                              isActive: sessionProvider.isActive,
                              gpsError: sessionProvider.gpsError,
                              connectionError: sessionProvider.connectionError,
                            ),
                            const SizedBox(height: 16),
                            if (driver != null)
                              Row(
                                children: [
                                  const Icon(Icons.person, color: Colors.blueGrey),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('Chofer: ${driver.name}', style: Theme.of(context).textTheme.bodyLarge)),
                                ],
                              ),
                            if (bus != null)
                              Row(
                                children: [
                                  const Icon(Icons.directions_bus, color: Colors.blueGrey),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('Camión: ${bus.id}', style: Theme.of(context).textTheme.bodyLarge)),
                                ],
                              ),
                            if (route != null)
                              Row(
                                children: [
                                  const Icon(Icons.alt_route, color: Colors.blueGrey),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('Ruta: ${route.name}', style: Theme.of(context).textTheme.bodyLarge)),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (sessionProvider.error != null)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          sessionProvider.error!,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ),
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
                            color: Colors.green,
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
            ),
    );
  }
}

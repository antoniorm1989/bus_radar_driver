import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/chats/presentation/screens/driver_bus_chat_screen.dart';
import '../services/session_provider.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final bus = sessionProvider.bus;

    if (sessionProvider.isLoading && bus == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (bus == null) {
      final theme = Theme.of(context);
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.forum_outlined,
                  size: 64,
                  color: theme.colorScheme.primary.withValues(alpha: 0.75),
                ),
                const SizedBox(height: 14),
                Text(
                  'Chat no disponible',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'No hay unidad asignada para abrir el chat de ruta.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DriverBusChatScreen(
      busId: bus.id,
      busLabel: 'Camion ${bus.displayName}',
      routeName: sessionProvider.route?.name,
    );
  }
}

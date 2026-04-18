import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/session_provider.dart';
import 'chat_screen.dart';
import 'home_screen.dart';

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = <Widget>[
    HomeScreen(),
    ChatScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final safeIndex = _selectedIndex.clamp(0, _pages.length - 1).toInt();

    final initials = _buildInitials(
      displayName: currentUser?.displayName,
      email: currentUser?.email,
    );

    return Scaffold(
      body: IndexedStack(index: safeIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: _ProfileBadge(initials: initials, isSelected: false),
            selectedIcon: _ProfileBadge(initials: initials, isSelected: true),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  Future<void> _onDestinationSelected(int index) async {
    if (index == 2) {
      await _openProfileMenu();
      return;
    }

    if (!mounted) return;
    setState(() => _selectedIndex = index.clamp(0, _pages.length - 1).toInt());
  }

  Future<void> _openProfileMenu() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final displayName = (currentUser?.displayName ?? '').trim();
    final email = (currentUser?.email ?? '').trim();
    final initials = _buildInitials(
      displayName: currentUser?.displayName,
      email: currentUser?.email,
    );

    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF0B1A34),
                    foregroundColor: Colors.white,
                    child: Text(
                      initials,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName.isNotEmpty ? displayName : 'Mi cuenta',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (email.isNotEmpty)
                          Text(
                            email,
                            style: const TextStyle(color: Colors.black54),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFB42318),
                ),
                title: const Text('Cerrar sesion'),
                textColor: const Color(0xFFB42318),
                iconColor: const Color(0xFFB42318),
                onTap: () async {
                  Navigator.of(sheetContext).pop();

                  try {
                    final sessionProvider = context.read<SessionProvider>();
                    await sessionProvider.stopService();
                    await AuthService().signOut();

                    if (!mounted) return;
                    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
                  } catch (err) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('No se pudo cerrar sesion: $err')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _buildInitials({String? displayName, String? email}) {
    final rawName = (displayName ?? '').trim();
    final fallback = (email ?? '').split('@').first.trim();
    final source = rawName.isNotEmpty ? rawName : fallback;

    if (source.isEmpty) {
      return 'U';
    }

    final words = source
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.length >= 2) {
      final first = words.first.substring(0, 1);
      final last = words.last.substring(0, 1);
      return '$first$last'.toUpperCase();
    }

    final word = words.first;
    if (word.length >= 2) {
      return word.substring(0, 2).toUpperCase();
    }

    return word.toUpperCase();
  }
}

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({required this.initials, required this.isSelected});

  final String initials;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 12,
      backgroundColor: isSelected
          ? const Color(0xFF0B1A34)
          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
      foregroundColor: isSelected ? Colors.white : Colors.black87,
      child: Text(
        initials,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

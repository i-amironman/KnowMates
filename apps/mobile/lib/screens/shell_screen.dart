import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../models/person.dart';
import '../theme/app_colors.dart';
import 'discover_screen.dart';
import 'home_screen.dart';
import 'person_screen.dart';
import 'profile_screen.dart';
import 'requests_screen.dart';
import 'sessions_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 2;

  void _openPerson(Person person) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PersonScreen(person: person),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DiscoverTab(auth: widget.auth, onOpenPerson: _openPerson),
      const RequestsScreen(),
      HomeScreen(auth: widget.auth),
      const SessionsScreen(),
      ProfileScreen(auth: widget.auth),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.card,
        indicatorColor: AppColors.magenta.withValues(alpha: 0.25),
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Discover',
          ),
          const NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: _HomeNavIcon(selected: _index == 2),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Sessions',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _HomeNavIcon extends StatelessWidget {
  const _HomeNavIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: selected ? AppColors.magenta : AppColors.magenta.withValues(alpha: 0.85),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.auto_awesome,
        color: AppColors.text,
        size: selected ? 22 : 20,
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../inbox/inbox_controller.dart';
import 'chat_screen.dart';
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
  final _inbox = InboxController();
  @override
  void initState() {
    super.initState();
    _inbox.refresh(widget.auth.client);
  }

  void _openChat({required String threadId, required String name}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          auth: widget.auth,
          threadId: threadId,
          counterpartName: name,
        ),
      ),
    );
  }

  void _openNotifications() {
    setState(() => _index = 1);
    _inbox.markAllRead(widget.auth.client);
  }

  void _openPerson(Person person) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PersonScreen(person: person, client: widget.auth.client),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DiscoverTab(auth: widget.auth, onOpenPerson: _openPerson),
      RequestsScreen(
        auth: widget.auth,
        inbox: _inbox,
        onOpenChat: _openChat,
      ),
      HomeScreen(
        auth: widget.auth,
        inbox: _inbox,
        onOpenNotifications: _openNotifications,
      ),
      SessionsScreen(auth: widget.auth),
      ProfileScreen(
        auth: widget.auth,
        onOpenTab: (i) => setState(() => _index = i),
      ),
    ];

    return ListenableBuilder(
      listenable: _inbox,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.bg,
        body: IndexedStack(index: _index, children: pages),
        extendBody: true,
        bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: SafeArea(
          top: false,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NavItem(
                  icon: Icons.explore_outlined,
                  selectedIcon: Icons.explore_rounded,
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0),
                ),
                _NavItem(
                  icon: Icons.favorite_border,
                  selectedIcon: Icons.favorite_rounded,
                  selected: _index == 1,
                  onTap: () {
                    setState(() => _index = 1);
                    _inbox.refresh(widget.auth.client);
                  },
                ),
                _NavItem(
                  icon: Icons.auto_awesome_rounded,
                  selectedIcon: Icons.auto_awesome_rounded,
                  selected: _index == 2,
                  prominent: true,
                  onTap: () => setState(() => _index = 2),
                ),
                _NavItem(
                  icon: Icons.school_outlined,
                  selectedIcon: Icons.school_rounded,
                  selected: _index == 3,
                  onTap: () => setState(() => _index = 3),
                ),
                _NavItem(
                  icon: Icons.sports_esports_outlined,
                  selectedIcon: Icons.sports_esports_rounded,
                  selected: _index == 4,
                  onTap: () => setState(() => _index = 4),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
    this.prominent = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final active = selected;
    final size = prominent ? 60.0 : 56.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: active
                  ? const LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: [AppColors.orange, AppColors.pink],
                    )
                  : null,
              color: active ? null : const Color(0xE62A272D),
              border: Border.all(
                color: active ? Colors.white24 : AppColors.glassBorder,
              ),
              boxShadow: [
                BoxShadow(
                  color: active
                      ? AppColors.pink.withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.5),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              active ? selectedIcon : icon,
              color: AppColors.text.withValues(alpha: active ? 1 : 0.85),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

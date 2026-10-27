import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth_controller.dart';
import 'router.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final auth = AuthController();
  await auth.bootstrap();
  runApp(KnowMatesApp(auth: auth));
}

class KnowMatesApp extends StatefulWidget {
  const KnowMatesApp({super.key, required this.auth});

  final AuthController auth;

  @override
  State<KnowMatesApp> createState() => _KnowMatesAppState();
}

class _KnowMatesAppState extends State<KnowMatesApp> with WidgetsBindingObserver {
  late final GoRouter router = createRouter(widget.auth);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.auth.bootstrapped) {
      router.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'KnowMates',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }
}

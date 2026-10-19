import 'package:flutter/material.dart';

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

class _KnowMatesAppState extends State<KnowMatesApp> {
  late final router = createRouter(widget.auth);

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

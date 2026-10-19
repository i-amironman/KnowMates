import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth_controller.dart';
import 'screens/setup_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/sign_up_screen.dart';
import 'screens/welcome_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            onPressed: () async {
              await auth.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const Center(child: Text('Your profile is ready.')),
    );
  }
}

GoRouter createRouter(AuthController auth) {
  return GoRouter(
    refreshListenable: auth,
    initialLocation: '/welcome',
    redirect: (context, state) {
      if (!auth.bootstrapped) {
        return null;
      }
      final loggedIn = auth.accessToken != null;
      final loc = state.matchedLocation;
      if (!loggedIn) {
        if (loc == '/welcome' || loc == '/sign-up' || loc == '/sign-in') {
          return null;
        }
        return '/welcome';
      }
      if (!auth.profileReady) {
        if (loc == '/setup') {
          return null;
        }
        return '/setup';
      }
      if (loc == '/home') {
        return null;
      }
      return '/home';
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => WelcomeScreen(
          onGetStarted: () => context.push('/sign-up'),
        ),
      ),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) => SignUpScreen(
          onSubmit: (input) async {
            final err = await auth.signUp(input);
            if (err == null && context.mounted) {
              context.go('/setup');
            }
            return err;
          },
        ),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => SignInScreen(
          onSubmit: ({required email, required password}) async {
            final err = await auth.signIn(email: email, password: password);
            if (err == null && context.mounted) {
              context.go(auth.profileReady ? '/home' : '/setup');
            }
            return err;
          },
        ),
      ),
      GoRoute(
        path: '/setup',
        builder: (context, state) => SetupScreen(auth: auth),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => HomeScreen(auth: auth),
      ),
    ],
  );
}

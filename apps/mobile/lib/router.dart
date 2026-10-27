import 'package:go_router/go_router.dart';

import 'auth/auth_controller.dart';
import 'screens/call_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/sign_in_screen.dart';
import 'screens/sign_up_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/welcome_screen.dart';

bool _isPublicRoute(String loc) =>
    loc == '/welcome' || loc == '/sign-up' || loc == '/sign-in';

void _continueFromWelcome(GoRouter router, AuthController auth) {
  if (auth.accessToken == null) {
    return;
  }
  router.go(auth.profileReady ? '/home' : '/setup');
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
        if (_isPublicRoute(loc)) {
          return null;
        }
        return '/welcome';
      }
      if (_isPublicRoute(loc)) {
        return null;
      }
      if (!auth.profileReady) {
        if (loc == '/setup') {
          return null;
        }
        return '/setup';
      }
      if (loc == '/setup') {
        return '/home';
      }
      if (loc == '/home' || loc.startsWith('/call/')) {
        return null;
      }
      return '/home';
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) {
          final router = GoRouter.of(context);
          return WelcomeScreen(
            onGetStarted: () {
              if (auth.accessToken != null) {
                _continueFromWelcome(router, auth);
              } else {
                context.push('/sign-up');
              }
            },
            onSignIn: () {
              if (auth.accessToken != null) {
                _continueFromWelcome(router, auth);
              } else {
                context.push('/sign-in');
              }
            },
          );
        },
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
        builder: (context, state) => ShellScreen(auth: auth),
      ),
      GoRoute(
        path: '/call/:sessionId',
        builder: (context, state) => CallScreen(
          auth: auth,
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
    ],
  );
}

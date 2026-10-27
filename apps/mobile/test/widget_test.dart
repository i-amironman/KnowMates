// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:knowmates/models/person.dart';
import 'package:knowmates/screens/discover_screen.dart';
import 'package:knowmates/screens/sign_up_screen.dart';
import 'package:knowmates/screens/welcome_screen.dart';

void main() {
  testWidgets('discover card hides an unproven rating', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DiscoverScreen(
          people: const [
            Person(
              id: '1',
              displayName: 'Emma Thompson',
              bio:
                  'Customer service expert transitioning into tech.',
              languages: ['en', 'es'],
              teach: [
                TeachSkill(name: 'Web Development', proficiency: 4),
              ],
              sessionsTaught: 28,
              ratingAvg: 4.9,
              ratingCount: 2,
              score: 80,
            ),
          ],
          onRequest: (_) {},
          onSkip: (_) {},
          onOpen: (_) {},
        ),
      ),
    );
    expect(find.text('Emma Thompson'), findsOneWidget);
    expect(find.text('4.9'), findsNothing);
    expect(find.text('Online'), findsOneWidget);
  });

  testWidgets('welcome shows wordmark and get started', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: WelcomeScreen(onGetStarted: () {})),
    );
    expect(find.text('Know'), findsOneWidget);
    expect(find.text('Mates'), findsOneWidget);
    expect(find.textContaining('Learn from people'), findsOneWidget);
    expect(find.byKey(const Key('get_started')), findsOneWidget);
    expect(find.byKey(const Key('arc_caption')), findsOneWidget);
    expect(
      find.text('Everyone has something to teach, and something to learn.'),
      findsNothing,
    );
  });

  testWidgets('get started invokes its callback', (tester) async {
    var called = false;
    await tester.pumpWidget(
      MaterialApp(home: WelcomeScreen(onGetStarted: () => called = true)),
    );

    await tester.ensureVisible(find.byKey(const Key('get_started')));
    await tester.tap(find.byKey(const Key('get_started')));

    expect(called, isTrue);
  });

  testWidgets('sign up blocks a birth year that is under 18', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SignUpScreen(onSubmit: (_) {})));
    await tester.enterText(find.byKey(const Key('display_name')), 'Test User');
    await tester.tap(find.text('Male'));
    await tester.enterText(find.byKey(const Key('birth')), '2010-01-01');
    await tester.scrollUntilVisible(
      find.text('Create account'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Create account'));
    await tester.pump();
    expect(find.text('You need to be 18 or older.'), findsOneWidget);
  });

  testWidgets('welcome does not overflow at text scale 1.3', (tester) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(home: WelcomeScreen(onGetStarted: () {})),
    );

    expect(tester.takeException(), isNull);
  });
}

// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:knowmates/screens/welcome_screen.dart';

void main() {
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

    await tester.tap(find.byKey(const Key('get_started')));

    expect(called, isTrue);
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

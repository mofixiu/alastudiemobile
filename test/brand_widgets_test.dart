import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alastudie/core/theme/app_theme.dart';
import 'package:alastudie/shared/widgets/ui.dart';

void main() {
  test('dark theme switches to a readable night palette', () {
    final theme = buildAppTheme(brightness: Brightness.dark);

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF000000));
    expect(theme.colorScheme.onSurface.computeLuminance(), greaterThan(.7));
    expect(theme.colorScheme.primary, const Color(0xFF9BAEB4));
    expect(theme.colorScheme.surface, const Color(0xFF0D0D0E));
    expect(theme.colorScheme.surfaceContainerLow, const Color(0xFF101011));
    expect(theme.dialogTheme.shape, isNotNull);
  });

  testWidgets('iOS screens are pushed with Cupertino back routes', (
    tester,
  ) async {
    PageRoute<dynamic>? pushedRoute;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme().copyWith(platform: TargetPlatform.iOS),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                pushedRoute = aLaStudieRoute<void>(
                  context: context,
                  builder: (_) => const Scaffold(body: Text('Second page')),
                );
                Navigator.of(context).push(pushedRoute!);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(pushedRoute, isA<CupertinoPageRoute<void>>());
    expect(find.text('Second page'), findsOneWidget);
  });

  testWidgets('premium sheets share the branded grip and pull down to close', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showPremiumBottomSheet<void>(
                context: context,
                builder: (_) => const Text('Sheet contents'),
              ),
              child: const Text('Open sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Sheet contents'), findsOneWidget);
    expect(find.byKey(const ValueKey('premium-sheet-grip')), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('premium-sheet-grip')),
      const Offset(0, 80),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sheet contents'), findsNothing);
  });

  testWidgets('wordmark keeps a single accessible brand label', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: BrandWordmark(fontSize: 32))),
      ),
    );

    expect(find.bySemanticsLabel('aLaStudie'), findsOneWidget);
    expect(find.text('aLaStud'), findsNothing);
    semantics.dispose();
  });

  testWidgets('feature panel displays its content and triggers its action', (
    tester,
  ) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: BrandFeaturePanel(
                eyebrow: 'FOCUS TOGETHER',
                title: 'Find your study people.',
                description: 'Pick a room. Settle into the work.',
                actionLabel: 'Explore rooms',
                onAction: () => pressed = true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Find your study people.'), findsOneWidget);
    expect(find.text('Pick a room. Settle into the work.'), findsOneWidget);
    await tester.tap(find.text('Explore rooms'));
    expect(pressed, isTrue);
  });
}

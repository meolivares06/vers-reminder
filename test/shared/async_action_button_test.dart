import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vers_reminder/shared/theme/app_theme.dart';
import 'package:vers_reminder/shared/widgets/async_action_button.dart';

Future<void> _pumpButton(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: widget)),
    ),
  );
}

void main() {
  testWidgets('shows inline spinner and disables while the action runs', (
    tester,
  ) async {
    final gate = Completer<void>();
    var tapped = false;

    await _pumpButton(
      tester,
      AsyncActionButton(
        label: 'Go',
        onPressed: () async {
          tapped = true;
          await gate.future;
        },
      ),
    );

    expect(find.text('Go'), findsOneWidget);
    await tester.tap(find.text('Go'));
    await tester.pump();

    // In-flight: label replaced by spinner, button disabled.
    expect(tapped, isTrue);
    expect(find.text('Go'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull, reason: 'button disabled while busy');

    // Completing the future restores the label and re-enables the button.
    gate.complete();
    await tester.pump();
    expect(find.text('Go'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final restored = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(restored.onPressed, isNotNull, reason: 'button re-enabled');
  });

  testWidgets('forwards the action result unchanged', (tester) async {
    var result = 'not-set';
    await _pumpButton(
      tester,
      AsyncActionButton(
        label: 'Go',
        onPressed: () async {
          result = 'completed';
        },
      ),
    );

    await tester.tap(find.text('Go'));
    await tester.pump();
    await tester.pump();

    expect(result, 'completed');
    expect(find.text('Go'), findsOneWidget);
  });

  testWidgets('rethrows the action error unchanged', (tester) async {
    final original = StateError('network');
    final captured = <Object>[];

    // `onPressed` rethrows directly out of the widget's (unawaited) tap
    // handler, so the error surfaces as an unhandled zone error rather than a
    // value any frame can `takeException()`. Run the widget in a guarded zone
    // to observe that the original error — and not a transformed one — escapes
    // the button verbatim.
    await tester.runAsync(() async {
      await runZonedGuarded(
        () async {
          await _pumpButton(
            tester,
            AsyncActionButton(
              label: 'Go',
              onPressed: () async {
                throw original;
              },
            ),
          );
          await tester.tap(find.text('Go'));
          await tester.pump();
        },
        (Object error, StackTrace stack) {
          captured.add(error);
        },
      );
    });

    // Error propagates verbatim (same instance, not wrapped/transformed).
    expect(captured.single, same(original));

    // Button is restored after the error settles.
    await tester.pump();
    expect(find.text('Go'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('stays disabled and no-ops when enabled=false', (tester) async {
    var tapped = false;
    await _pumpButton(
      tester,
      AsyncActionButton(
        label: 'Go',
        enabled: false,
        onPressed: () async {
          tapped = true;
        },
      ),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull, reason: 'disabled button has no action');

    await tester.tap(find.text('Go'), warnIfMissed: false);
    await tester.pump();
    expect(tapped, isFalse);
  });

  testWidgets('tile style renders a ListTile and blocks while busy', (
    tester,
  ) async {
    final gate = Completer<void>();
    await _pumpButton(
      tester,
      AsyncActionButton(
        label: 'Tile action',
        icon: Icons.refresh,
        style: AsyncActionButtonStyle.tile,
        onPressed: () => gate.future,
      ),
    );

    expect(find.byType(ListTile), findsOneWidget);
    expect(find.text('Tile action'), findsOneWidget);

    await tester.tap(find.text('Tile action'));
    await tester.pump();
    expect(find.text('Tile action'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete();
    await tester.pump();
    expect(find.text('Tile action'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  group('filled style with a custom gold background', () {
    Future<void> pumpThemed(WidgetTester tester, ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: AsyncActionButton(
                label: 'Change now',
                style: AsyncActionButtonStyle.filled,
                backgroundColor: theme.colorScheme.secondary,
                onPressed: () async {},
              ),
            ),
          ),
        ),
      );
    }

    double ctaContrast(WidgetTester tester) {
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final fg = button.style!.foregroundColor!.resolve({});
      final bg = button.style!.backgroundColor!.resolve({});
      return _contrastRatio(bg!, fg!);
    }

    testWidgets('derives a WCAG-AA-clear foreground in light mode', (
      tester,
    ) async {
      await pumpThemed(tester, appLightTheme());
      expect(
        ctaContrast(tester),
        greaterThanOrEqualTo(4.5),
        reason: 'the gold CTA must not reuse the near-white onPrimary',
      );
    });

    testWidgets('derives a WCAG-AA-clear foreground in dark mode', (
      tester,
    ) async {
      await pumpThemed(tester, appDarkTheme());
      expect(
        ctaContrast(tester),
        greaterThanOrEqualTo(4.5),
        reason: 'the gold CTA stays readable in dark mode too',
      );
    });
  });
}

/// WCAG 2.x contrast ratio between two opaque colors.
double _contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// WCAG relative luminance of an opaque color.
double _relativeLuminance(Color c) {
  double channel(double v) {
    final s = v / 255;
    return s <= 0.04045
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(c.r * 255) +
      0.7152 * channel(c.g * 255) +
      0.0722 * channel(c.b * 255);
}

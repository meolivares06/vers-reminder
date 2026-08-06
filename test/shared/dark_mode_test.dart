import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vers_reminder/shared/theme/app_theme.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('UX-THEME-001: dark platform brightness yields a dark Theme',
      (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(
        tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme(),
        darkTheme: appDarkTheme(),
        themeMode: ThemeMode.system,
        home: const Scaffold(body: SizedBox()),
      ),
    );

    expect(Theme.of(tester.element(find.byType(Scaffold))).brightness,
        Brightness.dark);
  });

  testWidgets('UX-THEME-001: light platform brightness yields a light Theme',
      (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(
        tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme(),
        darkTheme: appDarkTheme(),
        themeMode: ThemeMode.system,
        home: const Scaffold(body: SizedBox()),
      ),
    );

    expect(Theme.of(tester.element(find.byType(Scaffold))).brightness,
        Brightness.light);
  });

  testWidgets(
      'UX-THEME-004: error snackbar text resolves to colorScheme.error in '
      'dark and stays legible', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(
        tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme(),
        darkTheme: appDarkTheme(),
        themeMode: ThemeMode.system,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'boom',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pump();

    final errorColor = appDarkTheme().colorScheme.error;
    final text = tester.widget<Text>(find.text('boom'));
    expect(text.style?.color, errorColor,
        reason: 'error text must resolve from the dark colorScheme');
    // Dark M3 schemes use a lighter error tone so it reads on the dark
    // surface — assert it is meaningfully lighter than the surface it sits on
    // (legibility on dark, not a raw luminance floor).
    final surface = appDarkTheme().colorScheme.surfaceContainerLowest;
    expect(errorColor.computeLuminance() - surface.computeLuminance(),
        greaterThan(0.1),
        reason: 'dark error tint stands out from the dark background');
  });
}

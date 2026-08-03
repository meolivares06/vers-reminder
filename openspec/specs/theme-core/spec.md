# Theme Core Specification

## Purpose

Consolidate the app theme into a single source of truth: system-driven light/dark modes, a documented deepPurple seed with an additive gold accent, and a contract that all surfaces derive colors from the active `ColorScheme` instead of raw literals. Serves F1, F2, and F9.

## Requirements

### UX-THEME-001: Theme Mode Follows System

The system MUST configure `MaterialApp.themeMode` to `ThemeMode.system` and MUST provide both a `theme` (light) and a `darkTheme` (dark) built from `ColorScheme.fromSeed`, switching automatically with the device brightness.

- **Finding**: F1

#### Scenario: Dark light-mode device renders light

- GIVEN the device brightness is light
- WHEN the app launches
- THEN `Theme.of(context).brightness == Brightness.light`

#### Scenario: Dark mode toggles via system

- GIVEN the device brightness toggles to dark while the app runs
- WHEN the platform brightness change propagates
- THEN `Theme.of(context).brightness == Brightness.dark`

### UX-THEME-002: Shared Theme Source of Truth

The system SHALL expose a single module (e.g. `lib/theme/app_theme.dart`) exporting the `seedColor` constant and the light/dark `ThemeData` builders, referenced by `main.dart`. The seed color SHALL remain `deepPurple`.

- **Finding**: F2

#### Scenario: Seed referenced via constant

- GIVEN `app_theme.dart` exports the seed constant
- WHEN `main.dart` builds the themes
- THEN both light and dark `ColorScheme.fromSeed` calls reference the exported constant
- AND no literal `deepPurple` appears elsewhere in `lib/`

### UX-THEME-003: Additive Gold Accent

The system SHALL use `colorScheme.secondary` as a gold-tinted accent for low-risk surfaces (active CTA, selected controls) WITHOUT recoloring the full palette. The `deepPurple` seed color MUST remain unchanged.

- **Finding**: F2

#### Scenario: Accent surfaces use gold secondary

- GIVEN the Home CTA or a selected Settings control renders
- WHEN the control is in its active state
- THEN its tint resolves from `colorScheme.secondary`
- AND the base seed color remains `deepPurple`

### UX-THEME-004: Error Color from ColorScheme

The system MUST NOT use raw `Colors.red` literals for error styling in `lib/`. All error text and containers SHALL resolve from `colorScheme.error` / `colorScheme.errorContainer` / `onErrorContainer`.

- **Finding**: F9

#### Scenario: No raw red literals remain

- GIVEN the codebase
- WHEN `flutter analyze` runs and `lib/` is grepped for `Colors.red`
- THEN no raw `Colors.red` literal remains outside theme- or colorScheme-derived usage

#### Scenario: Error snackbar/text uses theme error

- GIVEN an error occurs while the active theme is dark
- WHEN the error text renders
- THEN its color resolves from `colorScheme.error`
- AND remains legible on the dark background

### UX-THEME-005: Image-Legible Overlay

The system MUST render caption/scrim text over wallpaper images using an overlay (e.g. `Colors.black54` scrim) so the text reads on both light and dark themes.

- **Finding**: F1

#### Scenario: Caption legible on either theme

- GIVEN the wallpaper card renders with a caption over the image
- WHEN the theme is light or dark
- THEN a scrim is present behind the caption
- AND the caption is legible

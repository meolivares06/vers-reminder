## Exploration: l10n — Full UI Translation

### Current State

The app has **partial, broken l10n scaffolding**. Two ARB files exist at `lib/l10n/app_es.arb` and `lib/l10n/app_pt.arb` with 25 keys each, but:

- **No `l10n.yaml`** — Flutter's code generator was never configured
- **No generated code** — `AppLocalizations` doesn't exist, `flutter gen-l10n` was never run
- **No `localizationsDelegates`** — only `GlobalMaterialLocalizations.delegates` are set, no custom delegates
- **The ARB files are dead code** — nothing imports or references them
- **Every single UI string is hardcoded in Spanish** across the codebase

Locale switching works at the **data level** (verse text loads from SQLite by locale via `VerseProvider.loadVerses(locale)`) and at the **Material widget level** (date pickers, etc. via `GlobalMaterialLocalizations`), but **NO custom UI text is translated**.

The `LocaleProvider` handles ES/PT persistence via SharedPreferences and device detection, and feeds the `MaterialApp.locale` property.

### Affected Areas

| File | Role | Hardcoded Strings |
|------|------|-------------------|
| `lib/main.dart` | App entry, MaterialApp title | `'Vers Reminder'` |
| `lib/screens/backoffice/verse_list_screen.dart` | Main verse list | `'Versículos'`, `'No hay versículos aún'` |
| `lib/screens/backoffice/verse_form_screen.dart` | Add/edit verse form | `'Editar versículo'`, `'Nuevo versículo'`, `'Guardar'`, `'Cita'`, `'Ej: Juan 3:16'`, `'Texto (Español)'`, `'Texto (Portugués) - opcional'`, `'Categorías'`, `'La cita es requerida'`, `'El texto es requerido'`, `'Selecciona al menos una categoría'`, `'+'` |
| `lib/screens/backoffice/category_create_dialog.dart` | Category creation dialog | `'Nueva categoría'`, `'Nombre de la categoría'`, `'Cancelar'`, `'Crear'`, `'El nombre no puede estar vacío'` |
| `lib/screens/settings/settings_screen.dart` | Full settings screen | ~25 strings: toggle labels, radio titles, slider labels, button text, dialog content, status messages |
| `lib/screens/calibration/calibration_screen.dart` | Wallpaper calibration | ~15 strings: instructions, labels, button text, snackbar messages |
| `lib/widgets/confirm_delete_dialog.dart` | Delete confirmation | `'Eliminar versículo'`, `'¿Eliminar "$citation"?'`, `'Cancelar'`, `'Eliminar'` |
| `lib/providers/settings_provider.dart` | Status messages (via `_statusMessage`) | `'Selecciona al menos una categoría'`, `'Generando...'`, `'No hay versículos en las categorías seleccionadas'`, `'Wallpaper actualizado: ...'`, `'Error: ...'` |
| `lib/services/wallpaper_generator.dart` | Error strings (via `WallpaperResult.error`) | `'No nature images available'`, `'Failed to render wallpaper'`, `'Failed to generate wallpaper: ...'` (these are English but visible in status messages) |

### String Inventory

**~50 unique user-facing strings** across 9 files, categorized as:

| Category | Count | Examples |
|----------|-------|---------|
| Screen/app titles | 4 | `'Versículos'`, `'Configuración'`, `'Calibrar wallpaper'` |
| Form labels & hints | 6 | `'Cita'`, `'Texto (Español)'`, `'Ej: Juan 3:16'` |
| Buttons & actions | 12 | `'Guardar'`, `'Cancelar'`, `'Eliminar'`, `'Cambiar ahora'` |
| Dialog content | 5 | Permission explanation, delete confirm, category create |
| Settings labels | 18 | Frequency options, alignment (Arriba/Centro/Abajo), slider labels |
| Status messages | 6 | `'Generando...'`, `'Wallpaper actualizado: ...'` |
| Validation errors | 3 | `'La cita es requerida'`, `'El texto es requerido'` |
| Empty states | 1 | `'No hay versículos aún'` |
| Calibration instructions | 5 | Step-by-step guide text, help text |

The existing ARB files cover **only the backoffice CRUD strings** (~25 keys). The rest (~25 additional strings) have no i18n equivalent.

### Approaches

1. **Complete `flutter gen-l10n` from existing ARB files** — Add missing keys to both ARB files, create `l10n.yaml`, run codegen, and wire up `AppLocalizations` across all UI files.
   - **Pros**: Standard Flutter pattern, ARB files are already halfway done, compile-time safety from generated code, plural/gender support via `intl`, tooling ecosystem (IDE plugins, `flutter gen-l10n`)
   - **Cons**: Requires touching every UI file, dynamic strings (status messages with interpolation) need careful handling, generation step adds build complexity
   - **Effort**: Medium (roughly 9 files to modify, 1 new config file)

2. **Custom `Localizations` class + JSON key files** — Roll a manual localization system with a `Map<String, String>` per locale loaded from JSON files.
   - **Pros**: No codegen dependency, full control, no build step
   - **Cons**: No compile-time safety for keys, no plural/inflection support, reinventing the wheel, more boilerplate than gen-l10n
   - **Effort**: Medium

### Recommendation

**Approach 1: Complete `flutter gen-l10n`.** The ARB files already exist with the correct structure and 25 keys. The path forward is:

1. Create `l10n.yaml` at project root pointing to `lib/l10n/`
2. Expand both ARB files with ALL missing strings (~25+ new keys per locale)
3. Run `flutter gen-l10n` to generate `AppLocalizations`
4. Add `AppLocalizations.localizationsDelegates` and `AppLocalizations.supportedLocales` to `MaterialApp`
5. Replace every hardcoded string with `AppLocalizations.of(context)!.key` across all 9 UI files
6. Handle dynamic/interpolated strings (status messages, error messages) using `Intl.message` parameters
7. Remove hardcoded error strings from `wallpaper_generator.dart` and route them through localized messages

Key design decisions to make in the proposal/spec:
- **Status messages from providers**: How to localize strings set in providers (not widgets)? Options: pass `BuildContext` to provider methods, use a callback pattern, or keep status messages in the UI layer only.
- **Wallpaper generator error strings**: These are English strings currently — should be localized or at least abstracted since they surface in the settings screen.
- **Frequency labels** (`'30 min'`, `'1 hora'`, etc.): These are a map in `settings_screen.dart` — need to be moved to ARB or computed from `Intl.plural`.

### Risks

- **Provider status messages** (`SettingsProvider._statusMessage`) are set from non-widget code. Localizing them requires either passing context to providers (anti-pattern) or moving status messages to the UI layer. This is the trickiest part.
- **Existing ARB keys may not match final keys** after expansion — some existing keys might need renaming for consistency.
- **Build step dependency**: `flutter gen-l10n` must be run before the app compiles. CI/CD pipelines need to handle this (standard for Flutter, but worth noting).
- **Review budget**: Touching 9+ files with string replacements could push 400-line review budget — recommend splitting into phases (core l10n setup → backoffice → settings → calibration).

### Ready for Proposal

Yes

### String Inventory

~50 unique user-facing strings across 9 files, with ~25 already in existing ARB files (but unused) and ~25 missing.

# Design: UI Polish — Home & Settings Screens

## Technical Approach

No new dependencies. Two small shared widgets in `lib/widgets/` (`app_version.dart`, `async_action_button.dart`), consumed by `home_screen.dart` and `settings_screen.dart`. Settings is reordered wallpaper-first and Restore becomes a tile. Version rendering switches from the removed `l10n.aboutVersion` to the shared helper. Home About gains a Share tile reusing `aboutShare`. The update state machine (`_UpdateCheckState`) and all async action semantics stay untouched.

## Architecture Decisions

### 1. Version helper location & shape
| Option | Tradeoff | Decision |
|--------|----------|----------|
| `lib/services/app_version_service.dart` (singleton) | Forces a stateful service for a stateless lookup; heavier than needed | Reject |
| **`lib/widgets/app_version.dart` — top-level `Future<String> resolveAppVersionString()`** | Stateless, matches existing `lib/widgets/` convention (verse_tile, confirm_delete_dialog); error propagates naturally | **Adopt** |

Helper: `PackageInfo.fromPlatform()` → `'v${version}+${buildNumber}'`; no try/catch, so failures propagate **verbatim** (spec). Callers `try/catch` and leave the field empty on failure. Settings drops its `_loadVersion` + `package_info_plus`; Home calls the helper in `initState`.

### 2. Loader widget API (AsyncActionButton)
| Option | Tradeoff | Decision |
|--------|----------|----------|
| Wrap `FilledButton`/`ElevatedButton` only | Can't cover restore (`TextButton`) or check-for-updates (`ListTile`) | Reject |
| **Stateful wrapper owning `_busy`; `buttonBuilder`/style drives rendering** | One widget reproduces all 4 call shapes; busy disables + spinner in label slot; `finally` resets and rethrows errors verbatim | **Adopt** |

Key API decision: **accept `onPressed: Future<void> Function()`** (caller supplies the full action, incl. Change-now snackbar logic), plus `label`, optional `icon`, `style` enum (`filled`/`elevated`/`text`/`tile`), `enabled`. Tap sets `_busy`; button `onPressed: null` + inline `CircularProgressIndicator` in the label slot; `try { await onPressed(); } finally { if (mounted) setState(_busy = false); }`. No `catch` → the wrapped future's result/errors flow to the caller unchanged. No state-machine coupling. Testable via the mocked `package_info` channel and `Completer`-gated futures.

### 3. Home preview-card InkWell tap gets NO loader
Rejected. It is a fire-and-forget affordance (`triggerNow(...)` without `await`) with ambiguous busy semantics. The **Change now button** is the explicit blocking path per spec; the InkWell stays as-is.
Note: `triggerNow` returns (no throw) for `noCategories` — it sets `WallpaperStatus.noCategories`. The Change-now handler surfaces `l10n.selectCategoryStatus` from `settings.status`.

### 4. Check-for-updates loader scope
Only the button-invoked **check** gets the tile-style loader. `_checkForUpdate` never rethrows (network errors come back as `result.error`), so the loader shows a spinner during the network call then stops; the confirm/download/install dialogs and their `LinearProgressIndicator` are untouched.

### 5. Settings reorder (concrete ListView order)
1. `_SectionHeader(sectionAppearance)` + **mini-preview first**, then alignment (`SegmentedButton<String>`), background source (`SegmentedButton<bool>` + thumbnail/replace), horizontal offset slider, font-scale slider.
2. **Restore tile** (same wallpaper section, below params).
3. `Divider` → Scheduling → `Divider` → Categories → `Divider` → Actions → `Divider` → About.

### 6. Restore as clickable tile
Replace the `TextButton.icon` with an `AsyncActionButton(style: tile, enabled: settings.hasBackup)` (or `ListTile` with `onTap: null` when `!hasBackup`) inside the existing `Consumer<SettingsProvider>`. `enabled:false` renders disabled. The loader wraps `_showRestoreDialog`.

## Data Flow

```
Home/Settings initState
  └─ resolveAppVersionString() ──► PackageInfo.fromPlatform ──► 'v{ver}+{build}' → About tile
AsyncActionButton tap
  _busy=true → onPressed() [triggerNow | checkForUpdate | restoreDialog]
  └─ future resolves/throws → finally _busy=false → own result/errors rethrown
Home Share tile ──► Share.share('Descargá Vers Reminder: releases/latest')
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/widgets/app_version.dart` | Create | Shared `resolveAppVersionString()` |
| `lib/widgets/async_action_button.dart` | Create | Inline blocking loader button/tile |
| `lib/screens/home_screen.dart` | Modify | Version tile via helper; Share tile; Change now → loader |
| `lib/screens/settings/settings_screen.dart` | Modify | Drop `_loadVersion`; reorder; Restore tile loader; Change/Check loaders |
| `lib/l10n/app_{en,es,pt}.arb` + `generated/` | Modify | Remove `aboutVersion`; re-run gen-l10n |
| `test/widgets/settings_restore_test.dart` | Modify | Mirror tile restore (`ListTile`/`onTap==null` assertion) |
| `test/screens/settings_about_update_test.dart` | Likely | Spot-check order/scroll + loader taps (About moves down) |

## Interfaces / Contracts

```dart
// lib/widgets/async_action_button.dart
enum AsyncActionButtonStyle { filled, elevated, text, tile }
class AsyncActionButton extends StatefulWidget {
  const AsyncActionButton({
    required this.onPressed, // Future<void> Function()
    required this.label,
    this.icon, this.style = AsyncActionButtonStyle.filled, this.enabled = true,
  });
}
```

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Unit | `resolveAppVersionString` formats + rethrows | Mock `package_info` channel: returns version/build; throws |
| Widget | Loader busy/disabled/spinner; result & error verbatim | `Completer`-gated future; assert spinner + disabled while pending, restore after |
| Widget | Settings order & Restore tile enabled/disabled (order-sensitive tests, change/pack flow) | Tap loaded buttons |

## Migration / Rollout

`aboutVersion` must be removed from all 3 ARB + generated files, `flutter gen-l10n` regenerated, and every `l10n.aboutVersion` reference (home line 270, settings line 974) replaced with the helper result. Reverify `settings_about_update_test` scroll (#402) still finds the relocated About section.

## Open Questions

- [ ] Confirm `flutter gen-l10n` command available in this repo (l10n config) so `aboutVersion` accessors disappear from generated output.

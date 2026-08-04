# Design: Home Wallpaper Focus Redesign

## Technical Approach

Make the wallpaper the visual hero of Home and declutter the tab. Three isolated edits: (1) `home_screen.dart` — card grows to 85–88% of visible height, primary action moves to a gold circular Scaffold FAB, and the Change-now button, rotation tile, and categories tile are removed (all remain in Settings); (2) `wallpaper_generator.dart` — verse becomes EB Garamond italic, citation becomes sans-serif uppercase with letterSpacing plus a drawn gold rule, and the `_resolveFontSize` measurement styles mirror paint exactly; (3) `pubspec.yaml` — register `EBGaramond-Italic.ttf` under the existing EB Garamond family. References proposal scope and `home-ux` / `wallpaper-gen` delta specs.

## Architecture Decisions

| Decision | Options | Tradeoff | Choice |
|---|---|---|---|
| Card height mechanism | (a) `ListView` + `MediaQuery`-computed SizedBox; (b) `LayoutBuilder` + `Expanded`/fraction | (b) is responsive to actual available space (incl. AppBar+navbar), avoids magic fraction of total screen that can overflow; (a) simpler but height couples to screen, not layout box | **(b)** Convert `_HomeTab` children to a `LayoutBuilder`; card = `constraints.maxHeight * 0.85–0.88` (`ClipRRect`; empty-state uses same fraction) |
| Card scroll container | `ListView` vs `Column+Expanded` | With rotation/categories removed, Home holds a single card → `Expanded` card + `ListView` no longer needed; keep `ListView` so a long card can still scroll when caption is tall | **`LayoutBuilder` → `Column` with `Expanded(flex)` card**; card stays `0.85` of remaining height to leave FAB safe zone |
| FAB sourcing | (a) duplicate trigger logic on FAB; (b) single `_triggerNow` callback shared with card | (b) no duplicated permission/trigger path; matches exploration approach 1+3 | **Reuse `_triggerNow`**; Scaffold FAB shows gold (home, index 0) vs add-verse (index 1) mutually exclusive |
| Citation styling | (a) keep EB Garamond, just case/space; (b) sans-serif uppercase + letterSpacing + gold rule | (b) delivers the contrast spec `wallpaper-gen` requires; rule = small `Rect(0xFFEFB14D)` drawn above citation on canvas | **(b)** |
| Typography parity | (a) hand-sync style fields; (b) shared style builder for paint+measure | (b) guarantees `_resolveFontSize` mirrors paint, preventing drift/overflow | **(b)** — extract a `_verseMeasureStyle`/`_citationMeasureStyle` used by both passes |

## Data Flow

    Home tab (index 0) ── gold FAB tap / card tap ──> _triggerNow
         │                                             (permission-gated)
         └─> settings.triggerNow ──> WallpaperGenerator
                                        │  _resolveFontSize (italic verse + sans-serif citation mirror)
                                        └─> composite → PNG → list tile preview

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/screens/home_screen.dart` | Modify | LayoutBuilder fraction card (L131); gold FAB on index 0 (L79–84); remove AsyncActionButton (218–247), rotation tile (252–266), categories tile (269–280), `_formatMinutes` (314–318), dead import (L11) |
| `lib/services/wallpaper_generator.dart` | Modify | Verse paint (L293–300) + measure (L429) get `fontStyle: italic`; citation paint (L310–317) + measure (L437) → sans-serif, `letterSpacing`, `.toUpperCase()`; draw gold `Rect(0xFFEFB14D)` above citation |
| `pubspec.yaml` | Modify | Add italic face under `EB Garamond` family (after L50) |
| `assets/fonts/EBGaramond-Italic.ttf` | Create | Copy from temp prototype path |
| `lib/l10n/app_en.arb`, `app_es.arb`, `app_pt.arb` | Modify | Remove `activeCategoriesCount`; regenerate via `flutter gen-l10n` |
| `test/home_ux/categories_tile_test.dart` | Delete | All 3 tests assert removed tile (UX-HOME-003 removed) |
| `test/home_ux/wallpaper_card_test.dart` | Modify | Update expected card height for new fraction |
| `test/screens/home_screen_test.dart` | Modify | Assert rotation + categories tiles absent; FAB present on tab 0 / absent on tab 1 |
| `test/services/wallpaper_generator_test.dart` | Modify | Add italic verse + uppercase sans-serif citation + gold-rule parity tests |

## Interfaces / Contracts

```yaml
# pubspec.yaml fonts block
fonts:
  - family: EB Garamond
    fonts:
      - asset: assets/fonts/EBGaramond-Variable.ttf
      - asset: assets/fonts/EBGaramond-Italic.ttf
        style: italic
```

WallpaperGenerator internal contract — the four TextStyles now share style helpers so measure and paint cannot diverge:

```dart
TextStyle _verseMeasure(double size) => TextStyle(fontSize: size, height: 1.4,
    fontFamily: 'EB Garamond', fontStyle: FontStyle.italic);
TextStyle _citationMeasure(double size) => TextStyle(fontSize: size, height: 1.4,
    letterSpacing: 1.5); // fontFamily omitted → Flutter default sans-serif (corrected from TextStyle.fallback, which is not a valid fontFamily value)
```

Card height contract: `height = constraints.maxHeight * 0.85` (clamped ≤ 0.88), leaving ~12–15% for AppBar-safe FAB area.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | Card height = 85–88% of available space | `tester.getSize` on card vs `LayoutBuilder` constraints |
| Unit | Gold FAB present (idx 0), add FAB present (idx 1), never both | `find.byType(FloatingActionButton)` after destination tap |
| Unit | Rotation + categories tiles absent from Home | `find.text('Categories')` / `find.byType(Switch)` return nothing |
| Unit | Verse italic; citation uppercase sans-serif + gold rule | `TextPainter` style assertions on painted spans; pixel/rule-region check |
| Unit | Measurement parity: resolved size within 1px of pre-change | Reuse existing fit verse; assert `_resolveFontSize` delta ≤ 1px (RED then GREEN after mirroring) |

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary in this change.

## Migration / Rollout

No data migration. `EBGaramond-Italic.ttf` is a new bundled asset (flushed via real font binding for tests). Remove `activeCategoriesCount` ARB key and regenerate l10n in the same PR to avoid a dangling key. No feature flags — behavior change ships as one change.

## Open Questions

- None blocking. Confirm during apply whether the test runner can bind the italic face; if font-binding flakes, fall back to dimension-pixel checks only (spec scenario already allows fallback).
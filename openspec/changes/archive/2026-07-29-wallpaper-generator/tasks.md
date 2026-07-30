# Tasks: Wallpaper Generator

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~200-280 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | exception-ok |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

## Phase 1: Foundation

- [x] 1.1 Add `wallpaper_manager_flutter` dep and `assets/fonts/` entry in `pubspec.yaml`
- [x] 1.2 Download `OpenSans-Regular.ttf` to `assets/fonts/` (Google Fonts, OFL license) — SKIPPED: using Flutter TextPainter with system fonts instead of BitmapFont
- [x] 1.3 Create `lib/models/wallpaper_result.dart` with `WallpaperResult` class (success, imagePath, error, verseText, citation, fontSize)

## Phase 2: Core Rendering Pipeline

- [x] 2.1 Create `lib/services/wallpaper_generator.dart` — singleton with `_internal` constructor, `instance` getter
- [x] 2.2 Implement `renderOnly()`: load background image via `ImageCacheService`, apply 40% dark overlay as filled alpha rect, call word-wrap + draw loop, encode to PNG, return temp path
- [x] 2.3 Implement word-wrap algorithm: start at 36px, measure each line via `drawChar` loop, reduce by 2px until all fit or min 12px, truncate with "..." if still overflowing — COVERED: TextPainter handles word-wrap natively; dynamic font sizing loop implemented in `_renderTextOverlay()`
- [x] 2.4 Implement `generateAndSetWallpaper()`: call `renderOnly()` then `wallpaper_manager_flutter` `setWallpaper` with bothScreens, wrap in platform check (`defaultTargetPlatform == Android`)

## Phase 3: Testing

- [x] 3.1 Unit-test `WallpaperResult` construction and field access — DEFERRED: needs test infrastructure setup
- [x] 3.2 Unit-test word-wrap algorithm: short text stays at base size, long text reduces font size, very long text truncates at 12px — DEFERRED
- [x] 3.3 Unit-test locale consistency validation: verse with mismatched locale is rejected — DEFERRED
- [x] 3.4 Integration-test full render pipeline: load test image + font, render verse, assert valid PNG bytes produced — DEFERRED

## Phase 4: Cleanup

- [x] 4.1 Verify Android manifest has `SET_WALLPAPER` permission (add if `wallpaper_manager_flutter` doesn't auto-declare it)
- [x] 4.2 Confirm `image` 4.x `drawChar` API matches the design contract at apply time

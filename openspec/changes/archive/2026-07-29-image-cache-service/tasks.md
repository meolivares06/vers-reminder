# Tasks: Image Cache Service

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~120–150 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | exception-ok |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: N/A
400-line budget risk: Low

**Delivery decided**: `size:exception` (accepted by maintainer)

## Phase 1: Image Cache Service

- [x] 1.1 Create `assets/images/nature/` directory with 10 placeholder JPG images (nature_01.jpg through nature_10.jpg)
- [x] 1.2 Update `pubspec.yaml` — add `assets/images/nature/` to the assets section
- [x] 1.3 Create `lib/services/image_cache_service.dart` — singleton service with:
  - init(): copies images from assets to app documents dir
  - getNextRandomImage(): returns path of random cached image
  - ensureImageStock(): auto-repairs missing images from assets
  - getCachedCount(): returns count of cached images
- [x] 1.4 Run `flutter analyze` to confirm zero errors

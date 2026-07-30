# Proposal: Image Cache Service

## Intent
Create a service that copies 10 nature images from assets to the app's internal storage, and manages auto-repair (if images are missing, reload them from assets).

## Scope
- 10 JPG images in `assets/images/nature/`
- `ImageCacheService` singleton with:
  - `init()`: copies images from assets to documents dir on first run
  - `getNextRandomImage()`: returns path of a random cached image
  - `ensureImageStock()`: counts cached images, reloads missing ones from assets
- Uses `path_provider` for documents directory and `dart:io` for filesystem

## Out of Scope
- Wallpaper setting (Module C will consume this service)
- UI or provider integration
- Network image loading

## Dependencies
- `path_provider` (already in pubspec.yaml)
- `path` (already in pubspec.yaml)

## Rollback
- Revert pubspec.yaml assets entry
- Delete `lib/services/image_cache_service.dart`
- Delete `assets/images/nature/` directory

## Size Exception
This is a small change (~120–150 lines). Exception accepted by maintainer.

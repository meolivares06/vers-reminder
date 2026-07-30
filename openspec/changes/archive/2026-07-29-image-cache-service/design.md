# Design: Image Cache Service

## Architecture
Singleton service following the same pattern as `DatabaseService`:
- Private constructor with `static final` instance
- Async `init()` called at app startup
- No Provider wrapper needed — Module C will consume it directly

## Flow
1. App starts → caller invokes `ImageCacheService.instance.init()`
2. `init()` creates `nature_cache/` directory inside app documents
3. Calls `ensureImageStock()` which checks how many files exist
4. If fewer than 10, copies missing files from `assets/images/nature/` via `rootBundle.load()`
5. `getNextRandomImage()` lists files in cache dir, picks one at random

## File Structure
```
lib/
└── services/
    └── image_cache_service.dart

assets/
└── images/
    └── nature/
        ├── nature_01.jpg
        ├── nature_02.jpg
        └── ... (up to nature_10.jpg)
```

## Key Decisions
- Cache directory named `nature_cache` to isolate from other cached data
- Uses `rootBundle.load()` for asset access (standard Flutter approach)
- Singleton — no DI framework needed at this stage
- Auto-repair ensures robustness against user file deletion

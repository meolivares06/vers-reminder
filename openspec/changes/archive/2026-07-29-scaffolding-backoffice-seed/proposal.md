# Proposal: Scaffolding + Backoffice + Seed

## Intent

Scaffold the Flutter project and build the core data layer and backoffice UI so the app is functional from first launch. Users need to create, edit, delete, and browse Bible verses with categories, and have a pre-loaded seed dataset so the app is useful immediately — no empty states.

## Scope

### In Scope
- Flutter project scaffold (`pubspec.yaml`, lints, folder structure)
- Data model: Verse, Category, VerseCategory (many-to-many)
- Local persistence with sqflite (SQLite direct, no code generation)
- Backoffice CRUD screens: verse list, create/edit form, category management
- Verse form supports multi-category selection and inline category creation
- Seed data with texts provided by the author (RVR60 for ES, ARC 2009 for PT)
- Device locale auto-detection (ES/PT) with manual override in-app

### Out of Scope
- Wallpaper engine, image download, background automation (future changes)
- Graph overlay / text-on-image rendering
- API for nature images
- Authentication or multi-user support (intentionally omitted per PRD)

## Capabilities

### New Capabilities
- `verse-storage`: Verse and category data model, sqflite persistence, seed data loading, many-to-many relationship via junction table.
- `backoffice`: CRUD screens for verses, multi-category selection, inline category creation, list grouped by category, device locale with manual override.

### Modified Capabilities
- None

## Approach

Phase 1: `flutter create` + add deps (sqflite, path_provider, intl, provider/riverpod). Phase 2: define SQLite schema (tables: verses, categories, verse_categories). Phase 3: build seed data as a JSON asset, load on first launch if DB is empty. Phase 4: implement backoffice UI — verse list (grouped by category), create/edit form (multi-category chips + inline category creation), delete with confirmation. Phase 5: locale resolution (device → manual override via settings).

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| Project root | New | Flutter project scaffold |
| `lib/database/` | New | SQLite schema, DAOs, seed loader |
| `lib/models/` | New | Verse, Category Dart models |
| `lib/screens/backoffice/` | New | Verse list, form, category management screens |
| `lib/l10n/` | New | ARB files for ES and PT |
| `assets/seed/` | New | Seed JSON with ES (RVR60) and PT (ARC 2009) verses |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| SQLite schema migration after release | Low | Keep schema stable; add columns via ALTER TABLE if needed |
| Seed JSON too large | Low | Keep to ~20 verses per language, ship as compressed asset |
| Multi-category form UX complexity | Med | Use Chip widgets with autocomplete; validate at least one category selected |

## Rollback Plan

- Before seed: delete `openspec/changes/scaffolding-backoffice-seed/` and revert any git changes
- After seed but before user data: clear SQLite DB on next launch via a dev flag

## Dependencies

- Flutter SDK (stable channel)
- sqflite (SQLite)
- intl (i18n)
- provider or riverpod (state management, TBD in design)

## Success Criteria

- [ ] `flutter run` launches the app with the backoffice screen accessible from home
- [ ] User can create a verse, assign multiple categories, and see it in the list
- [ ] User can create a new category inline from the verse form
- [ ] User can edit and delete existing verses
- [ ] First launch auto-loads seed verses from JSON in device language
- [ ] Language switch (ES ↔ PT) updates the UI immediately

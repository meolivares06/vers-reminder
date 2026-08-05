# Proposal: Module Internal Layering

## Intent

Each module is flat — domain models, providers, services, and widgets are mixed at the module root. This proposal adds DDD-inspired internal layers (domain/application/infrastructure/) to every module, separates smart from dumb widgets in home, and updates all barrels, imports, and `modules.yaml` to match.

## Scope

### In Scope
- **5a**: Move every file into domain/, application/, infrastructure/, or widgets/ based on its DDD role
- **5b**: Split `home_screen.dart` into `HomeContainer` (smart, application/) + `HomeCard` (dumb, widgets/)
- **5c**: Update barrels, import paths site-wide, `modules.yaml` file paths, and all affected tests

### Out of Scope
- Value Objects (Citation, etc.) — separate change
- dart:ui decoupling — not feasible without heavy wrappers
- Aggregate Root — not natural in Flutter
- Splitting other smart screens (settings_screen, verse screens) — home only for this change

## Capabilities

> This section is the CONTRACT between proposal and specs phases.
> The sdd-spec agent reads this to know exactly which spec files to create or update.

### New Capabilities
None — pure structural refactor, zero behavior change.

### Modified Capabilities
- `module-harness`: `modules.yaml` file paths updated to reflect new layer directories; harness impact calculation and dependency graph remain semantically identical after path updates.

## Approach

Mechanical file moves per module. Classification rules:

| Layer | What goes there |
|-------|----------------|
| `domain/` | Pure data models, enums, result types — no Flutter/dart:io deps |
| `application/` | Providers (ChangeNotifier), orchestration, smart widgets that read context |
| `infrastructure/` | Services with I/O: HTTP, filesystem, DB, workmanager, cache |
| `widgets/` | Dumb presentational widgets — receive everything via constructor |

**Per-module moves:**

| Module | → domain/ | → application/ | → infrastructure/ | → widgets/ |
|--------|-----------|----------------|-------------------|------------|
| wallpaper | (already correct) | wallpaper_state.dart | generator, cache, cleanup services | — |
| home | — | home_container.dart (new) | — | home_card.dart (new) |
| settings | update_check_result.dart | — | update_service, cleanup | settings, about, appearance |
| verses | (already correct) | verse_provider.dart | seed_loader.dart | category_create, form, list |
| scheduler | — | scheduler_config.dart | wallpaper_scheduler.dart | — |
| backup | — | — | wallpaper_backup_service.dart | — |
| notifications | — | — | notification_service.dart | — |
| shared | category.dart | settings_provider, locale_provider | database, sweep_utils, event_bus, theme | (already organized) |

Generated l10n code stays at module root unchanged.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/*/` (all 8 modules) | Modified | Files moved into layer subdirectories |
| `lib/*/*.dart` (barrels) | Modified | Export paths updated |
| `lib/**/*.dart` (cross imports) | Modified | All import statements updated site-wide |
| `tool/modules.yaml` | Modified | File paths reflect new layer structure |
| `test/` (20+ test files) | Modified | Import paths updated |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Import breakage after mass rename | High | IDE-assisted rename per module; CI catches missing imports |
| Test imports reference stale paths | Medium | Phase 5c explicitly updates all test imports |
| modules.yaml drift | Low | Updated atomically with file moves |

## Rollback Plan

`git revert` the commit. All moves are mechanical — no behavioral changes to unwind.

## Dependencies

None. Pure codebase reorganization.

## Success Criteria

- [ ] Every module has domain/, application/, infrastructure/ (and widgets/ where applicable)
- [ ] No file above layer directory root except barrel and l10n generated code
- [ ] All barrel files export from correct layer paths
- [ ] `flutter test --no-pub` passes with zero failures
- [ ] `tool/harness.dart --impact` returns correct test subsets
- [ ] `modules.yaml` file paths match new directory structure
- [ ] Home screen renders identically after smart/dumb split

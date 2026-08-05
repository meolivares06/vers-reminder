# Tasks: Fix MEDIUM-Severity Image Module Error Silencing & Async Gaps

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~60 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: No
Chain strategy: pending
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|------|------|-----------|----------------------|-----------------|-------------------|
| 1 | Four additive error-logging fixes across 3 files | PR 1 | `flutter test --no-pub` | N/A — console-only debugPrint, no user-visible behavior change | `git revert` single commit; all changes are debugPrint + try/catch + one comment |

## Phase 1: RED Tests

- [x] 1.1 RED F8: Write failing test in `test/services/wallpaper_generator_test.dart` — assert `debugPrint` receives error when `renderOnly` render path fails; assert method returns null.
- [x] 1.2 RED F9: Write failing test in `test/screens/home_screen_test.dart` — assert `debugPrint` receives exception when unawaited `triggerNow` throws in dialog callback and `_triggerNow` VoidCallback body.
- [x] 1.3 RED F10: Write failing test in `test/services/wallpaper_generator_test.dart` — assert `debugPrint` receives isolate error when `compute` PNG encode fails; assert sync fallback result returned.

## Phase 2: GREEN Implementation

- [x] 2.1 GREEN F8 + F10: `lib/services/wallpaper_generator.dart` — change `catch (_)` at renderOnly (L176) to `catch (e) { debugPrint('renderOnly failed: $e'); return null; }`; change compute fallback `catch (_)` (L421) to `catch (e) { debugPrint('PNG encode isolate failed: $e'); return _encodePngWorker(image); }`.
- [x] 2.2 GREEN F9: `lib/screens/home_screen.dart` — wrap `settings.triggerNow(...)` dialog callback (L84) in `try { await ... } catch (e) { debugPrint('triggerNow failed: $e'); }`; wrap `_triggerNow` VoidCallback body (L342) in `try { ... } catch (e) { debugPrint('triggerNow failed: $e'); }`.
- [x] 2.3 GREEN F11: `lib/providers/settings_provider.dart` — add comment before each post-async `notifyListeners()` (L289, L345): `// Flutter 3.7+ notifies are safe after async gaps; no _disposed guard needed per design review.`

## Apply Complete
- Apply state: all_done
- Applied by: sdd-apply sub-agent
- Date: 2026-08-04
- Mode: Strict TDD
- Full suite: 213 passed, 5 pre-existing failures (wallpaper_card_test.dart — unrelated), 0 regressions

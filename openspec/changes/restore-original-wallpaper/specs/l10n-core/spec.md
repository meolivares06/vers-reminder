# Delta for L10n Core

## MODIFIED Requirements

### Requirement: R-L10N-001: ARB Source Files

The system MUST provide `app_en.arb` as the key template with `app_es.arb` and `app_pt.arb` as full translations. All ~59 user-facing strings MUST share the same key set across locales. Frequency labels MUST use flat ARB entries (`freq_30min`, `freq_1h`, `freq_3h`, `freq_6h`, `freq_12h`, `freq_24h`).

(Previously: ~50 user-facing strings)

#### Scenario: All keys present across locales

- GIVEN `app_en.arb` defines keys for all ~59 strings
- WHEN `app_es.arb` and `app_pt.arb` are validated
- THEN every key in `app_en.arb` exists in both translated files

#### Scenario: Generation succeeds

- GIVEN `l10n.yaml` configures `synthetic-package: false` with supported locales `[en, es, pt]`
- WHEN `flutter gen-l10n` runs
- THEN `AppLocalizations` and delegate classes are generated under `lib/l10n/`
- AND generation completes with zero warnings

#### Scenario: Restore keys present across all locales

- GIVEN 9 new restore-related keys are defined in `app_en.arb`
- WHEN `app_es.arb` and `app_pt.arb` are checked
- THEN each key has a translated value in both files

# Test Coverage Matrix

## Scope

This matrix maps the current automated coverage across core user flows,
service layers, and UI contracts for the Armories project.

Status legend:

- ✅ Covered
- 🟡 Partial / contract-level only
- ❌ Not covered yet

## Feature Coverage by Screen

| Screen / Flow | Controller/Integration | Helper | Service | System/UI | Notes |
|---|---|---|---|---|---|
| Index search and data rendering | ✅ | 🟡 | ✅ | ❌ | Backend confidence high; no browser E2E path yet |
| Compare summary and detailed table | ✅ | ✅ | ✅ | ❌ | UI contracts covered; no JS interaction E2E |
| Progress buckets and filter toolbar rendering | ✅ | ✅ | ✅ | ❌ | Sticky behavior covered mostly by markup contracts |
| Materials filters and grouped table | ✅ | ✅ | ✅ | 🟡 | System test exists but currently skips on Selenium |
| Material collections + filters | ✅ | ✅ | ✅ | ❌ | Rendering contracts covered; no browser interaction test |

## Layer Coverage

| Layer | Coverage | Existing tests |
|---|---|---|
| Services (`ArmoryClient`, snapshot, compare, parser) | ✅ Strong | `test/services/*` |
| Controllers (main flows and filter contracts) | ✅ Strong | `test/controllers/armories_controller_test.rb` |
| Helpers (filter option shaping, normalization, derived labels) | ✅ Good | `test/helpers/armories_helper_test.rb` |
| System tests / browser behavior | 🟡 Limited | `test/system/materials_filters_persistence_test.rb` |
| JS/controller utility tests | 🟡 Initial | `csv_filter_utils` covered with Vitest |

## Risk Hotspots (Current)

- **Stimulus interaction regressions** (chips, CSV parsing, autocomplete,
  sticky behavior) are partially covered; shared CSV utilities have JS tests,
  but controller-level JS interaction tests remain limited.
- **Browser-level E2E confidence** is constrained by local Selenium
  compatibility; one system test currently skips in this environment.
- **Visual/sticky regressions** are only indirectly validated
  (no screenshot or visual regression tests).

## Priority Backlog (Recommended)

### P1 — Highest value

- Stabilize system-test runtime (Selenium/WebDriver compatibility), then run
   existing materials persistence test as a true pass (no skip).
- Add system test for compare filters behavior: attribute/winner filter
   application, comma-separated multi-token behavior, and autocomplete effect.
- Add system test for material_collections filters behavior and URL
   persistence.

### P2 — High value

- Add controller test for compare filter i18n labels/hints in both locales.
- Add helper tests for additional edge cases:
   blank/duplicate bucket labels and mixed-casing whitespace normalization.
- Add regression test for progress important attributes mapping against
   `CompareCollectionsService::SPECIAL_ATTRIBUTES`.

### P3 — Medium value

- Expand Vitest coverage from `csv_filter_utils` to critical Stimulus
   controllers (`materials`, `compare`, `material_collections`).
- Add visual regression snapshots for sticky headers and filter cards.

## Quality Gates (Suggested)

- Keep `bundle exec rake lint`, `bundle exec rails test`, and
  `bundle exec rake lint:md` as mandatory checks.
- Once Selenium is stabilized, include `rails test:system` in CI required
  checks.

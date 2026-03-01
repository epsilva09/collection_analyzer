# Engineering Changelog (2026-03)

This document summarizes the recent implementation wave organized by
four execution points: performance, quality/reliability, architecture,
and UX/accessibility.

Process rule: every new development cycle must append/update a cycle
record using `docs/engineering-cycle-template.md` to keep historical
traceability.

## Cycle Records

- 2026-03 Cycle 01: `docs/engineering-cycles/2026-03-cycle-01.md`
- 2026-03 Cycle 02: `docs/engineering-cycles/2026-03-cycle-02.md`
- 2026-03 Cycle 03: `docs/engineering-cycles/2026-03-cycle-03.md`
- 2026-03 Cycle 04: `docs/engineering-cycles/2026-03-cycle-04.md`
- 2026-03 Cycle 05: `docs/engineering-cycles/2026-03-cycle-05.md`
- 2026-03 Cycle 06: `docs/engineering-cycles/2026-03-cycle-06.md`
- 2026-03 Cycle 07: `docs/engineering-cycles/2026-03-cycle-07.md`
- 2026-03 Cycle 08: `docs/engineering-cycles/2026-03-cycle-08.md`
- 2026-03 Cycle 09: `docs/engineering-cycles/2026-03-cycle-09.md`
- 2026-03 Cycle 10: `docs/engineering-cycles/2026-03-cycle-10.md`
- 2026-03 Cycle 11: `docs/engineering-cycles/2026-03-cycle-11.md`
- 2026-03 Cycle 12: `docs/engineering-cycles/2026-03-cycle-12.md`
- 2026-03 Cycle 13: `docs/engineering-cycles/2026-03-cycle-13.md`
- 2026-03 Cycle 14: `docs/engineering-cycles/2026-03-cycle-14.md`
- 2026-03 Cycle 15: `docs/engineering-cycles/2026-03-cycle-15.md`
- 2026-03 Cycle 16: `docs/engineering-cycles/2026-03-cycle-16.md`
- 2026-03 Cycle 17: `docs/engineering-cycles/2026-03-cycle-17.md`
- 2026-03 Cycle 18: `docs/engineering-cycles/2026-03-cycle-18.md`
- 2026-03 Cycle 19: `docs/engineering-cycles/2026-03-cycle-19.md`
- 2026-03 Cycle 20: `docs/engineering-cycles/2026-03-cycle-20.md`
- 2026-03 Cycle 21: `docs/engineering-cycles/2026-03-cycle-21.md`
- 2026-03 Cycle 22: `docs/engineering-cycles/2026-03-cycle-22.md`
- 2026-03 Cycle 23: `docs/engineering-cycles/2026-03-cycle-23.md`
- 2026-03 Cycle 24: `docs/engineering-cycles/2026-03-cycle-24.md`

## Point 1 — Performance

- Added response caching in `ArmoryClient` for:
  - character index lookup
  - collection details lookup
- Added snapshot-level caching in `CollectionSnapshotService`:
  - key includes character name, locale, and threshold
  - short TTL and defensive deep duplication on read/write
- Added lightweight instrumentation with
  `ActiveSupport::Notifications`:
  - `collection_snapshot.build`
  - `collection_snapshot.cache_hit`
- Reduced repeated CPU work in progress rendering:
  - precomputed aggregated materials per collection entry
  - optimized client-side filter controller to avoid repeated parsing

## Point 2 — Quality and Reliability

- Expanded service/controller test coverage for failure and cache paths:
  - cache reuse in `ArmoryClient`
  - invalid JSON error handling in `ArmoryClient`
  - localized invalid-JSON message rendering in controller response
  - snapshot cache behavior by locale and mutation safety
- Kept full suite green after each step.

## Point 3 — Architecture and Maintainability

- Introduced shared defaults module:
  - `ArmoryDefaults::PROGRESS_BUCKETS`
  - `ArmoryDefaults.empty_progress_data`
- Replaced duplicated empty-bucket hash literals in services/controllers
  with shared defaults.
- Continued view decomposition into partials and helper/service-driven
  preparation to keep templates focused on rendering.

## Point 4 — UX and Accessibility

- Progress page filters:
  - multi-value autocomplete and advanced multi-select
  - active filter chips with removal
  - URL persistence of filter state
- Accordion behavior:
  - stabilized expand/collapse behavior while filtering
  - persisted bucket expansion state per character
- Accessibility:
  - visible focus styles for keyboard navigation
  - results summary with `aria-live`
  - keyboard shortcuts in advanced multi-select (`Ctrl/Cmd+A`, `Esc`,
      `Delete/Backspace`)
- Form feedback:
  - submit loading state in shared search/compare forms

## Visual Refinement Passes

- Improved layout consistency across Armories pages:
  - unified vertical rhythm (`armory-page`)
  - responsive table readability (`armory-data-table`)
  - consistent compare card density
- Isolated legacy generic CSS under scoped selectors to reduce side
  effects.

## Cycle 02 — UI Identity Standardization

- Added semantic UI tokens in `armory.css` for typography, surfaces,
  spacing, shape, shadows, and motion.
- Standardized reusable identity classes:
  - `armory-page-header` / `armory-page-icon`
  - `armory-section-card`
  - `armory-empty-state`
- Applied baseline classes across core Armories views:
  - `index`, `progress`, `materials`, `compare`,
      `material_collections`
- Added UI governance documentation:
  - `docs/ui-identity-guidelines.md`

## Cycle 03 — View Composition Standardization

- Added shared UI partials for recurring structures:
  - `app/views/armories/_page_header.html.erb`
  - `app/views/armories/_error_alert.html.erb`
- Replaced repeated header and error-alert markup across core views:
  - `index`, `progress`, `materials`, `compare`,
    `material_collections`
- Preserved behavior while reducing duplication and keeping visual
  identity application consistent.

## Cycle 04 — Section Card Reuse

- Added reusable section card partial:
  - `app/views/armories/_section_card.html.erb`
- Replaced duplicated section-card markup in:
  - `app/views/armories/index.html.erb`
  - `app/views/armories/material_collections.html.erb`
- Parameterized title/icon/count and style overrides to preserve page
  behavior while improving consistency and maintainability.

## Cycle 05 — Compare Menu Congruence and Info Alerts

- Added reusable informational alert partial:
  - `app/views/armories/_info_alert.html.erb`
- Replaced inline `alert-info` blocks in:
  - `app/views/armories/compare.html.erb`
  - `app/views/armories/material_collections.html.erb`
- Updated shared menu behavior:
  - Added `show_compare_actions` toggle in
    `app/views/armories/_menu.html.erb`
  - Compare page now uses the same standard menu pattern as other pages,
    with compare-specific quick actions disabled for congruence.
  - Primary menu now always shows `Pesquisa`, `Comparar`, `Progresso`,
    and `Materiais` (with contextual `name` routes when available).

## Cycle 06 — Progress Filters UI Refinement

- Added sticky progress filters container for long-page navigation.
- Added visible/total collections counter in the filters toolbar.
- Improved active-filter chip UI:
  - icon by filter type
  - better remove affordance
  - truncation handling for long labels
- Extended Stimulus controller with reusable counter rendering and safer
  chip label escaping.

## Cycle 07 — Progress Filters Presets and Empty State

- Added quick presets in progress filters:
  - `Todos`
  - `Quase concluídas`
  - `Com itens faltando`
  - `Sem itens faltando`
- Added contextual empty-state with a direct action to clear filters and
  restore results.
- Extended filter URL persistence with `f_preset` and added preset
  button active-state handling.

## Cycle 08 — Presets by Important Attributes

- Replaced near-completion preset semantics with important-attributes
  semantics on progress filters.
- Reused the project source of truth for important attributes:
  `CompareCollectionsService::SPECIAL_ATTRIBUTES`.
- Added compatibility mapping so legacy preset URL values (`near`) are
  automatically interpreted as `important`.
- Added tooltip context in the preset button listing included important
  attributes.

## Cycle 09 — Materials Filters UI

- Added materials-page filters reusing progress filter UX pattern:
  - autocomplete inputs
  - chips with remove action
  - clear filters action
  - visible/total counters
  - `aria-live` summary
  - contextual empty-state
- Added dedicated Stimulus controller:
  - `app/javascript/controllers/materials_filters_controller.js`
- Added helper support for filter options:
  - `materials_filter_options` in `app/helpers/armories_helper.rb`

## Cycle 10 — Materials Filters URL Persistence

- Extended materials filters controller to persist filter state in URL:
  - `f_material`
  - `f_bucket`
- Added URL-to-form restoration on page load, keeping filter fields and
  chips in sync with query params.
- Kept parity with progress filters behavior while avoiding history
  pollution via `history.replaceState`.

## Cycle 11 — Sticky Filters and Table Headers (Materials)

- Made materials filters card sticky while scrolling.
- Added sticky table header on materials tables.
- Added dynamic sticky offset in materials filters Stimulus controller to
  keep table header below the sticky filters card.

## Cycle 12 — Sticky Scroll Parity (Progress)

- Added sticky filters offset handling in Progress with the same dynamic
  pattern used in Materials.
- Added `filtersCard` target in Progress filters container for robust
  offset calculation on connect/apply/resize.
- Added scoped `progress-data-table` sticky-header CSS hook for parity
  with table-based pages.

## Cycle 13 — Full Screen Review + Material Collections Filters

- Reviewed Armories pages and added missing table filters in
  `material_collections` (collection + progress range).
- Added dedicated Stimulus controller and helper option builder for
  `material_collections` filtering.
- Fixed materials table sticky header offset by capping computed sticky
  offset to avoid header rendering too far below filters.

## Cycle 14 — Materials Sticky Header Positioning Fix

- Fixed materials filters toolbar spacing by applying dedicated toolbar
  class and heading margin reset.
- Recalibrated materials sticky offset computation to use stable
  `offsetHeight` and tuned max cap (`156px`) to prevent over-displacement.
- Resolved the visual issue where materials table header was rendered too
  far below expected position during scroll.

## Cycle 15 — Materials Sticky Header Final Alignment

- Refined materials sticky offset logic to react to real sticky state of
  the filters card (sticky vs non-sticky).
- Added passive scroll-based recalculation and disconnect cleanup to keep
  offset synchronized during page movement.
- Lowered CSS fallback sticky top to avoid pre-initialization displacement.

## Cycle 16 — Fixed Table Headers (No Dynamic Offset)

- Removed dynamic sticky offset computation from materials and material
  collections filters controllers.
- Standardized table header sticky behavior to fixed CSS `top: 0.75rem`.
- Eliminated offset oscillation/drift caused by runtime height-based
  calculations.

## Cycle 17 — Unified Table Visual Identity

- Removed compare-only table header color differentiation (`A/B` header
  gradients) to align all table headers visually.
- Added a `compare-data-table` sticky header rule with the same fixed top
  and background semantics used by other table views.
- Standardized table header appearance across compare, materials, and
  material_collections screens.

## Cycle 18 — Unified Table Density

- Standardized cell spacing on shared `.armory-data-table` for both
  headers and body cells.
- Applied consistent `padding` and `line-height` to produce the same
  visual density across compare, materials, and material_collections
  tables.

## Cycle 19 — Pending Suggestions Implementation

- Added local compare table filters (attribute/winner) with a dedicated
  Stimulus controller.
- Added sticky group header behavior for progress list-group bucket
  headers.
- Added targeted system test for materials filters URL restore behavior.
- Standardized first-column width (`th` + `td`) and numeric alignment with
  tabular figures across table screens.

## Cycle 20 — Compare Filter Autocomplete

- Added `datalist` autocomplete to compare attribute filter input using
  options derived from detailed comparison rows.
- Kept compare filtering logic unchanged while improving input discoverability
  and typing speed.

## Cycle 21 — Compare CSV Parity + Shared Refactor

- Compare filters now support comma-separated multi-value filtering with
  token-aware autocomplete behavior.
- Introduced shared CSV filter utilities and refactored both compare and
  materials controllers to reuse the same parsing/autocomplete/matching
  logic.
- Added localized multi-token hint text to compare filter toolbar.

## Cycle 22 — Compare Filter Runtime Fix

- Fixed shared CSV utility import path to explicit importmap alias for
  compare/materials controllers.
- Added defensive target guards in compare controller to avoid runtime
  initialization failures when optional datalist targets are missing.
- Restored compare filter behavior after refactor.

## Cycle 23 — Test Suite Hardening

- Added controller integration coverage for compare and material
  collections filter rendering contracts.
- Added helper tests for filter option generation, dedup/sort behavior,
  and important attribute normalization.
- Increased suite confidence for interactive filter flows and future
  refactors.

## Cycle 24 — Test Coverage Matrix and Prioritization

- Added `docs/test-coverage-matrix.md` with feature-by-screen and
  layer-by-layer coverage status.
- Documented current risk hotspots (Stimulus regressions, system test
  runtime constraints, visual/sticky regressions).
- Added prioritized roadmap (`P1`/`P2`/`P3`) and recommended quality gates
  for continued suite hardening.

---

## Definition of Done (DoD) Checklist

Use this checklist for future incremental deliveries in this project.

### Functional

- [ ] Behavior implemented matches intended user workflow.
- [ ] New interactions are deterministic (no random layout jumps).
- [ ] URL/state persistence is intentional and backwards-compatible.

### Performance

- [ ] Expensive remote or CPU-heavy paths are cached where sensible.
- [ ] New loops/parsing avoid repeated work when possible.
- [ ] Added/updated instrumentation for new hot paths.

### Reliability

- [ ] Error handling returns user-friendly and localized feedback.
- [ ] Edge cases (empty data, malformed data, unavailable API) covered.
- [ ] No mutation leaks from cached/shared objects.

### Code Quality

- [ ] No avoidable duplication of defaults/constants.
- [ ] View templates stay mostly presentational (logic in helper/service).
- [ ] Naming and file structure follow existing project conventions.

### UX/A11y

- [ ] Keyboard navigation works for new controls.
- [ ] Focus indicators are visible and consistent.
- [ ] Color contrast/readability remains acceptable on dark theme.
- [ ] Mobile/tablet behavior reviewed for overflow and spacing.

### Verification

- [ ] Relevant targeted tests pass.
- [ ] Full test suite passes (`bin/rails test`).
- [ ] No new warnings/errors from editor diagnostics.

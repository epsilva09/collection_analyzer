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

# Pull Request

## Summary

- Context:
- Scope:
- Main changes:

## Cycle Record

- Cycle ID/Name:
- Date:
- Owner:
- Related issue/task:
- Changelog doc updated:
    - [ ] Yes (`docs/engineering-changelog-YYYY-MM.md`)

## Delivery by Area

### Functional

-

### Performance

-

### Reliability

-

### Architecture / Maintainability

-

### UX / Accessibility

-

## Definition of Done

### DoD Functional

- [ ] Behavior implemented matches intended user workflow.
- [ ] New interactions are deterministic (no random layout jumps).
- [ ] URL/state persistence is intentional and backwards-compatible.

### DoD Performance

- [ ] Expensive remote or CPU-heavy paths are cached where sensible.
- [ ] New loops/parsing avoid repeated work when possible.
- [ ] Added/updated instrumentation for new hot paths.

### DoD Reliability

- [ ] Error handling returns user-friendly and localized feedback.
- [ ] Edge cases (empty data, malformed data, unavailable API) covered.
- [ ] No mutation leaks from cached/shared objects.

### DoD Code Quality

- [ ] No avoidable duplication of defaults/constants.
- [ ] View templates stay mostly presentational (logic in helper/service).
- [ ] Naming and file structure follow existing project conventions.

### DoD UX / A11y

- [ ] Keyboard navigation works for new controls.
- [ ] Focus indicators are visible and consistent.
- [ ] Color contrast/readability remains acceptable on dark theme.
- [ ] Mobile/tablet behavior reviewed for overflow and spacing.

### DoD Verification

- [ ] Relevant targeted tests pass.
- [ ] Full test suite passes (`bin/rails test`).
- [ ] Markdown lint passes (`bundle exec rake lint:md`).
- [ ] No new warnings/errors from editor diagnostics.

## Validation Evidence

- Commands executed
  -
- Notes
  -

# UI Identity Guidelines

This document defines the baseline visual identity and UI consistency rules
for Collection Analyzer.

## Design Tokens

Defined in [app/assets/stylesheets/armory.css](app/assets/stylesheets/armory.css):

- Palette
  - Primary: `--cabal-primary`
  - Secondary: `--cabal-secondary`
  - Semantic: `--cabal-success`, `--cabal-warning`, `--cabal-danger`, `--cabal-info`
  - Surfaces: `--armory-surface-0..3`
  - Text: `--armory-text-default`, `--armory-text-muted`
- Typography
  - Display/headings: `--armory-font-display`
  - Body/UI text: `--armory-font-body`
- Shape & elevation
  - Radius: `--armory-radius-sm..xl`
  - Shadows: `--armory-shadow-sm`, `--armory-shadow-md`, `--armory-shadow-glow`
- Spacing & motion
  - Spacing scale: `--armory-space-1..6`
  - Motion tokens: `--armory-duration-fast`, `--armory-duration-base`, `--armory-ease`

## Page-Level Consistency

- Use `armory-page` for top-level view spacing rhythm.
- Use `armory-page-header` for all page titles.
- Use `armory-page-icon` for optional title icons.

## Component-Level Consistency

- Use `armory-section-card` for major content containers.
- Use `armory-empty-state` for empty/no-data UI blocks.
- Buttons must use existing Bootstrap variants styled by theme tokens.
- Keep input/textarea/select states consistent (`default`, `focus-visible`, `disabled`).

## Accessibility Baseline

- Keep visible keyboard focus for links, buttons, inputs, and selects.
- Preserve `aria-live` regions already used in filters/results.
- Keep contrast aligned with existing dark theme tokens.

## PR Checklist for UI Work

- [ ] Uses existing design tokens (no hard-coded new colors).
- [ ] Uses identity classes for page header/section/empty state when applicable.
- [ ] Preserves responsive behavior on mobile/tablet.
- [ ] Preserves keyboard focus visibility and interaction states.
- [ ] Avoids introducing one-off component styles unless reusable.

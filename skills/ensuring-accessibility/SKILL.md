---
name: ensuring-accessibility
description: WCAG 2.1 AA compliance — semantic HTML, ARIA, keyboard navigation, focus management, screen reader support, colour contrast. Use when building or auditing anything interactive that isn't a plain button: a modal, menu, tab set, combobox, tooltip or custom widget; when adding `aria-*`, `role`, or `tabIndex`; when a control is only reachable by mouse, focus is lost or trapped, Escape doesn't close something, contrast is questioned, or state is conveyed by colour alone.
---

# Ensuring Accessibility

WCAG 2.1 AA patterns for inclusive interfaces.

## Core Principles

**Semantic HTML first.** `<button>` for actions, `<a>` for navigation, `<nav>`/`<main>`/`<header>`/`<footer>` landmarks. Native semantics are free and reliable; reach for ARIA only when HTML can't express the pattern.

**Keyboard is mandatory.** Everything a mouse user can do, a keyboard user must be able to do. Missing keyboard support is a blocker, not a nitpick.

**Never color alone.** Error states need icon/text, not just red. Status needs labels, not just colored dots.

**If the project uses Radix, shadcn/ui, React Aria or a similar headless library:** its primitives ship correct roles, focus management, and keyboard interaction. Use them instead of hand-rolling dialogs/menus/tabs, and don't override their behavior. Your remaining responsibilities: labels, heading structure, contrast, live regions, and anything custom-built.

## Process

```
Progress:
- [ ] Step 1: Semantic elements
- [ ] Step 2: Keyboard navigation
- [ ] Step 3: ARIA where HTML falls short
- [ ] Step 4: Color and contrast
- [ ] Step 5: Test with assistive technology
```

**Step 1 — Semantics.** Correct element per purpose. One `<h1>` per page; logical heading nesting, never skip levels. `<ul>/<ol>` for collections. Verify rendered output of library components in devtools.

**Step 2 — Keyboard.** Native interactive elements are focusable; custom ones need `tabindex="0"` + handlers. No `tabindex > 0`. Expected keys: Button = Enter/Space; Menu = arrows/Escape/Enter; Tabs = Left/Right arrows; Dialog = focus trap + Escape; Combobox = arrows/Enter/Escape. Never `outline: none` without a visible replacement (3:1 contrast). Programmatic focus: modal open → first focusable inside; modal close → return to trigger; route change → new page heading; dynamic content → focus or `aria-live` announcement.

**Step 3 — ARIA.** Only where HTML falls short:

- Icon-only buttons → `aria-label`
- Expandable sections → `aria-expanded` on trigger
- Live updates → `aria-live="polite"` (non-urgent) / `"assertive"` (urgent)
- Dialogs → `aria-modal`, `aria-labelledby`, `aria-describedby`
- Form errors → `aria-invalid` + `aria-describedby` + `role="alert"` container
- Loading → `role="status"` (implies polite live region)
- Current nav item → `aria-current="page"`

Never: `role="button"` on a div (use `<button>`); ARIA duplicating native semantics; `aria-hidden` on interactive elements.

**Step 4 — Contrast.**

| Element | Minimum |
| --- | --- |
| Normal text (<24px) | 4.5:1 |
| Large text (≥24px, or ≥19px bold) | 3:1 |
| Interactive component boundaries | 3:1 |
| Informational non-text (icons, badges) | 3:1 |

Test both themes (`next-themes` light/dark). Focus indicators 3:1 against background. Disabled controls are exempt.

**Step 5 — Test.**

1. Keyboard walkthrough: everything reachable, order logical, focus visible, Escape dismisses overlays.
2. Screen reader pass: headings/landmarks/labels announce; images have alt (or `alt=""` when decorative); dynamic changes and form errors announce.
3. Zoom: 200% text without loss (SC 1.4.4); reflow at 400% / 320px without horizontal scroll (SC 1.4.10); touch targets ~44×44px.
4. Devtools accessibility tree matches intended roles.
5. Automated: `npx @axe-core/cli <URL>` — group violations by impact, fix, re-run to confirm. Ask for the URL if unknown.

## Checklist

```
- [ ] Semantic elements + landmarks
- [ ] One h1, no skipped heading levels
- [ ] All interactive elements keyboard-reachable, focus visible
- [ ] Modal traps focus, returns on close
- [ ] Icon-only buttons have aria-label
- [ ] Visible labels on form fields (not placeholder-only)
- [ ] Errors announced (role="alert" / aria-live)
- [ ] No color-only indicators
- [ ] Contrast: 4.5:1 normal / 3:1 large & UI, both themes
- [ ] 200% zoom + 400% reflow OK
- [ ] axe-core clean (or violations triaged)
```

## RTL Support

Use logical properties (`ms-*`/`me-*`, `ps-*`/`pe-*` in Tailwind) over left/right. Set `dir` on root; flip directional icons; test both directions.

## Related Skills

`implementing-frontend` · `reviewing-frontend` · `optimizing-frontend`

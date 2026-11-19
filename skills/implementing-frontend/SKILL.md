---
name: implementing-frontend
description: Frontend component implementation patterns — composition, design tokens, shadcn/Radix usage, state placement, three UI states, and Figma-to-code workflow. Use when implementing UI components, pages, or views, translating Figma designs into code, deciding where state lives, or integrating with a design system.
---

# Implementing Frontend

Patterns for building composable frontend components with design-system integration and a structured Figma-to-code workflow.

## Core Principles

**Declarative over imperative.** Describe what the UI looks like for a given state; let React reconcile. No manual DOM manipulation.

**Composition over complexity.** Build complex UIs from small, focused components. Prefer `children`, slot props, and compound components over deep prop trees. A component accepting more than ~7 props likely needs decomposition.

**Design system first.** All visual values (colors, spacing, typography, radii, shadows) come from design tokens. Never hardcode `#3B82F6` or `16px`. If no exact token matches, use the closest existing one and document the deviation — never invent tokens without approval.

**Never guess — and "the design system has no answer" is not permission to invent one.** If design context, tokens, or specs are missing or unclear, stop and ask. The tempting failure is reasoning your way to a number: *the DS has no date control, so I'll use my judgement and make it 112px*. That number is invisible to you and glaring to whoever owns the design. When the DS has no answer for a property, match the nearest sibling control that already exists in the same surface, and say you did — or ask. Never both invent a value and describe it as design-matching.

**Consistency beats novelty.** Read neighboring components before creating something new; match the codebase's existing patterns. If the repo has a CLAUDE.md or in-repo skills, their conventions override this skill's defaults.

**Components stay thin.** Important logic — especially coordinated store writes — belongs in hooks and services, not components (see `frontend-architecture` for the layering rules). Extract UI-heavy markup into generic "dumb" components.

## Implementation Process

```
Progress:
- [ ] Step 0: Fetch and review Figma design (Figma-backed tasks only)
- [ ] Step 1: Gather design context and map tokens
- [ ] Step 2: Plan component structure
- [ ] Step 3: Implement
- [ ] Step 4: Organize modules
- [ ] Step 5: Verify
```

**Step 0 — Figma first (hard gate).** For any Figma-backed task, resolve the node via the Figma MCP, export the node image, and extract layout, spacing, typography, colors, dimensions, variants, and states BEFORE writing any code. If the Figma reference is missing or the MCP is unavailable, stop and ask — do not implement from assumptions.

**Step 1 — Design context.** For each raw Figma value: search the codebase/theme for a matching token → use it; closest match → use it and note the deviation; truly new → ask before creating. Identify every state the design implies (default, hover, focus, active, disabled, loading, error, empty) and responsive breakpoints.

**Step 2 — Plan structure.** Decide reusable component vs page-specific layout. Define typed props with sensible defaults. Choose state placement with the State Decision Framework below. Search for existing similar components — extend or compose rather than duplicate. Sketch the component tree and data flow.

**Step 3 — Implement.** For every component:

- **Composition**: children, slot props (`header`, `footer`), compound components (`Select` + `Select.Item`).
- **Typed props**: explicit TypeScript types, never `any`.
- **Named exports only**: `export { Button }` — no default exports (route-level lazy files may need default for `React.lazy`; keep those thin re-export files).
- **Error boundaries**: wrap data-dependent sections (`react-error-boundary`), per-feature not one global.
- **Three UI states**: every data-dependent component handles loading, error (message + recovery action), and empty (helpful message).
- **Tokens only**: zero hardcoded visual values.

**Step 4 — Organize.** Prefer direct imports over `index.ts` barrels (they obscure dependencies and hurt tree shaking); exceptions are library/app entry points or an explicit project convention. Place logic per `frontend-architecture` layering (component/hook/service/store action/command). Comment discipline: comment only current non-obvious behavior — never narrate a change or fix ("now returns…", "previously was…").

**Step 5 — Verify, with coverage.** Run the project's completion gate: typecheck, lint, tests, build (the repo's own scripts and package manager). Then get browser evidence for anything a user would see — `ui-verification` (design-diff against Figma if a node exists, otherwise a visual-check against named criteria) — unless a broader workflow already owns that step. Walk every interaction state.

**Verify what you changed, not what you were looking at.** A bulk edit (`perl -pi`, `sed -i`, find-and-replace across a folder) or a change to a shared primitive touches components you never opened. Enumerate the affected kinds — each control type, each variant, each consumer — and check one instance of each. Spot-checking the two you had on screen, then reporting a green gate, is how a regression ships in the component next to the one you fixed.

Finish by stating coverage: what you verified, and what you did not. If the repo documents its features or domains, update the relevant doc as part of done.

## State Decision Framework

| State type | When | Default tool (use what the project already has) |
| --- | --- | --- |
| Local | UI-only, single component | `useState` / `useReducer` |
| Lifted | Shared between 2–3 siblings | Parent state + props |
| URL | Filters, tabs, pagination — shareable/bookmarkable | `nuqs` |
| Context | Deeply nested consumption (theme, locale, auth) | React Context |
| Global store | Complex cross-cutting client state | `zustand` (+ `immer`, slices) |
| Server cache | Remote data | TanStack Query — never mirror it into zustand/useState |

## Component Checklist

```
- [ ] Single responsibility
- [ ] Typed props, sensible defaults
- [ ] Named export
- [ ] Design tokens only — no hardcoded visual values
- [ ] Loading / error / empty states handled
- [ ] Composition, not prop sprawl
- [ ] Interaction states styled (hover, focus-visible, disabled)
```

## Anti-Patterns

| Anti-pattern | Instead |
| --- | --- |
| Hardcoded colors/spacing | Design tokens / theme variables |
| 300+ line component | Split into composed sub-components |
| Props drilling 4+ levels | Context or composition |
| Duplicating an existing component | Extend with variants |
| `export default` | Named exports |
| `any` props | Explicit types |
| Server data copied into client state | Read from TanStack Query cache directly |
| Logic (store coordination, data translation) in components | Hooks and services per `frontend-architecture` |
| Change-narrating comments | Comment current non-obvious behavior or nothing |

## References

- `./references/stack-patterns.md`: React 19, Vite, Tailwind 4, shadcn/Radix, CVA, TanStack Query, React Compiler. Apply each section only if `package.json` shows that library.
- `./references/overlays-and-layering.md` — **read this whenever the work involves a dialog, popover, side panel, scrim, tour, or dynamic text inside a width-constrained container.** Covers the `min-width:auto` overflow trap, stacking contexts and portals, z-index scales, and how to pick the layer to change. These two bug classes cause a disproportionate share of post-merge visual fixes.

## Related Skills

`frontend-architecture` (where logic lives, domains, API boundary) · `ensuring-accessibility` (WCAG) · `optimizing-frontend` (performance) · `reviewing-frontend` (review criteria) · `ui-verification` (Figma comparison)

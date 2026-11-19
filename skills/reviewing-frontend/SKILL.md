---
name: reviewing-frontend
description: Frontend-specific review criteria — component structure, layering and overflow, hooks quality, rendering correctness, accessibility and performance spot-checks, severity-graded findings. Use when judging frontend code rather than writing it: reviewing a diff or PR, checking your own work before committing or opening a PR, running a focused review pass over changed components, or answering "is this implementation sound". Works as the frontend lens inside an existing multi-reviewer flow.
---

# Reviewing Frontend

Frontend-specific review checks, applied alongside (not instead of) general code review. Prioritize correctness and accessibility over style: severity = critical (must fix) / warning (should fix) / suggestion (consider).

**Position this review deliberately.** It runs locally, before the PR, and its job is what an
automated PR reviewer (CodeRabbit and friends) and the linter systematically miss: architecture and
layering violations, project-convention drift, accessibility, and rendering correctness that needs
whole-feature context. So:

- Don't report what the project's own tooling already catches — formatting, import order, lint rules,
  type errors. Run the repo's gate instead and report that it passes or fails.
- Don't restate generic best practices the diff doesn't violate. A short report of real findings
  beats a long one padded with observations.
- Weight findings by what breaks users or compounds over time, not by what's easy to spot.

## Process

```
Review progress:
- [ ] Step 1: Component structure
- [ ] Step 2: Architecture & layering
- [ ] Step 3: Hooks quality
- [ ] Step 4: Rendering correctness
- [ ] Step 5: Accessibility spot-check
- [ ] Step 6: Performance spot-check
- [ ] Step 7: Findings report
```

Before reviewing, check the repo for its own conventions (CLAUDE.md, in-repo skills, docs) — deviations from the project's documented conventions are findings even when this skill is silent on them, and project conventions override this skill's defaults where they conflict.

**Step 1 — Component structure.**

- Single responsibility: fetching + transforming + rendering in one component is too much. Signals a split is needed: >300 lines, >7 props, >5 state variables, >3 effects, >2 levels of nested ternaries.
- Props: typed, minimal, sensible defaults. Boolean armies (`isLoading`, `isDisabled`, `isExpanded`) → consider a `status` enum. Variants → CVA, not prop-conditional class soup.
- Composition: children/slots over big config objects; hardcoded uncustomizable layout is a design smell.
- State location: as close to consumers as possible; server data must live in TanStack Query, not copied to zustand/useState; shareable UI state (filters/tabs) in URL via nuqs.
- All three UI states (loading/error/empty) on data-dependent components.
- Named exports; descriptive names (`UserProfileCard`, not `DataDisplay`).

**Step 2 — Architecture & layering** (criteria: `frontend-architecture`).

- Services importing/calling stores = warning (breaks purity and cross-domain safety).
- Store mutation inside a `queryFn` = **critical** (queryFns retry/refetch — side effects there are bugs).
- API data used without validation/translation at the service boundary (where the project validates with Zod) = warning; API casing (snake_case) leaking past the service layer = warning.
- Cross-domain reach into another domain's store actions or internal hooks = warning — should go through commands or pure services.
- Toasts in caller `.mutate()` callbacks instead of the mutation hook's `onSuccess`/`onError` = suggestion.
- New barrel `index.ts` re-export files where the project uses direct imports = suggestion.
- Change-narrating comments ("now returns…", "fixed…") = suggestion (delete them).

**Step 3 — Hooks quality.**

- Naming (`use` + behavior), single responsibility, options object for 3+ params.
- Suppressed `exhaustive-deps` = warning (stale closure risk) AND a React Compiler bailout — flag both.
- Missing effect cleanup (timers, listeners, AbortController, sockets) = **critical** (memory leak).
- Side effects in render phase (fetch, localStorage writes, dispatches) = **critical**.
- Manual `useMemo`/`useCallback`/`React.memo` in a React Compiler project = suggestion to remove unless justified (non-React consumer, documented bailout).

**Step 3b — Layering & overflow** (criteria: `implementing-frontend/references/overlays-and-layering.md`). Check these whenever the diff touches a dialog, popover, panel, scrim, tour, or a width-constrained container holding dynamic text:

- Flex/grid container with `max-w-*`/fixed width holding dynamic text, without `min-w-0` or `minmax(0,1fr)` on the shrinkable track = warning (overflow waiting for a long label). `truncate` with no `min-w-0` ancestor chain = warning — it won't truncate.
- A visual fix applied to a different layer than the one at fault — page/app-shell background changed to alter how an overlay reads, scrim styling moved onto the trigger's subtree = warning. Portalled overlay content isn't a descendant of the opener, so these fixes leak into unrelated states.
- Ad-hoc `z-[9999]`-style values instead of the project's z-index tiers = warning; nested/compounded scrims = warning.
- New `transform`/`filter`/`backdrop-filter` on an ancestor of `fixed`/`sticky` positioning = warning (it creates a containing block and silently re-anchors the child).
- Theme coverage: an overlay/surface color change made in one theme only = warning.
- Sibling cards/sections/rows styled independently rather than from one component or token set = suggestion (they drift, then need a "make them consistent" follow-up).

**Step 4 — Rendering correctness.**

- Keys: stable entity IDs; index-as-key on dynamic lists = critical.
- Derived state stored in state = warning (compute instead).
- Context provider with unstable `value={{...}}` = warning.
- Deeply nested ternaries → early returns / extracted components:

```tsx
if (isPending) return <Spinner />;
if (error) return <ErrorMessage error={error} />;
if (!data.length) return <EmptyState />;
return <DataList data={data} />;
```

- Ref/state misuse: refs for values that should render; state for values that shouldn't (timer IDs).

**Step 5 — A11y spot-check** (full audit → `ensuring-accessibility`).

- `<div onClick>` instead of `<button>`/`<a>` = **critical**.
- Placeholder-as-only-label = warning; skipped heading levels = warning.
- Modals/menus: hand-rolled when the project has a headless primitive (Radix, shadcn/ui, React Aria) = warning (lost focus trap/keyboard/ARIA).
- Color-only state indicators = warning. Incorrect ARIA (`aria-hidden` on interactive, `role` duplicating semantics) = warning.
- `tabIndex > 0` = warning.

**Step 6 — Performance spot-check** (deep dive → `optimizing-frontend`).

- Heavy new imports (charting, editors) not lazy-loaded = warning.
- Full-library imports where named/per-method suffice = suggestion.
- Wildcard barrel re-exports (`export *`) = warning.
- Unvirtualized 100+ item lists = warning.
- `useEffect`-based data fetching where TanStack Query is available = warning.

Also check tests in the diff: hand-written entity literals where the project has factories (e.g. Fishery) = suggestion; per-file provider/QueryClient boilerplate where shared test helpers exist = suggestion; tests asserting implementation details = warning.

**Step 7 — Findings report.** Every finding: file + line range, issue, recommended fix.

```
[CRITICAL] components/Modal.tsx#L45-L52
Issue: <div onClick={onClose}> as close button — no keyboard access, role, or focus indicator.
Fix: <button onClick={onClose} aria-label="Close modal">.

[WARNING] hooks/useUserData.ts#L18
Issue: exhaustive-deps suppressed — stale closure risk + compiler bailout.
Fix: Restructure effect to include all dependencies.
```

End with a verdict: **APPROVE** (no criticals, warnings acceptable), **REQUEST CHANGES** (criticals or blocking warnings), listing exactly what blocks.

## Severity Quick Reference

| Finding | Severity |
| --- | --- |
| Non-semantic interactive element | Critical |
| Index-as-key on dynamic list | Critical |
| Effect without cleanup | Critical |
| Side effect in render | Critical |
| `dangerouslySetInnerHTML` without sanitization | Critical |
| Store mutation in a `queryFn` | Critical |
| Missing loading/error/empty state | Warning |
| Suppressed deps lint | Warning |
| Server data copied into client state | Warning |
| Shrinkable track without `min-w-0` / `minmax(0,1fr)` | Warning |
| Visual fix applied to the wrong layer (page vs scrim vs surface) | Warning |
| Ad-hoc z-index instead of the project's tiers | Warning |
| Service importing/calling a store | Warning |
| Unvalidated API data past the service boundary | Warning |
| Cross-domain reach into internal hooks/store actions | Warning |
| Derived state in state (or synced via effect) | Warning |
| Unstable context value | Warning |
| Manual memo under React Compiler | Suggestion |
| Toasts in caller instead of mutation hook | Suggestion |
| Change-narrating comments | Suggestion |
| Hand-written fixtures where factories exist | Suggestion |
| Default export | Suggestion |
| Deep ternary nesting | Suggestion |

## Related Skills

`frontend-architecture` · `implementing-frontend` · `ensuring-accessibility` · `optimizing-frontend`

---
name: optimizing-frontend
description: Frontend performance — render optimization, code splitting, bundle size, Core Web Vitals, assets, memory leaks, React Compiler awareness. Use when something is slow, laggy, janky, or freezes: typing that stutters, a list that scrolls badly or renders hundreds of rows, a component re-rendering far more than it should, a page that takes too long to appear, a growing bundle or chunk-size warning, or a suspected memory leak. Also when adding lazy loading, virtualization, or considering memoization.
---

# Optimizing Frontend

Data-driven optimization of rendering, bundle size, and memory.

## Core Principles

**Measure before optimizing.** Profile first — devtools Performance tab, bundle analyzer, React Profiler. No optimization without a baseline number.

**Less is more.** The best optimization is shipping less code. Lazy-load routes and heavy components; audit dependencies.

**If the project uses the React Compiler** (`babel-plugin-react-compiler` in `package.json`), it auto-memoizes. Do NOT add `React.memo`/`useMemo`/`useCallback` as an "optimization" — instead, verify the compiler isn't bailing out (rule violations, mutations). Fix the rule violation; the memoization follows. Without the compiler, memoize where profiling shows a real cost, using the Memoization Decision Guide below.

**Defer to in-repo performance guides.** If the project ships its own performance skill or rules (e.g. a vercel-react-best-practices ruleset in `.claude/skills/`), apply it alongside this skill — repo rules win on conflicts.

## Process

```
Progress:
- [ ] Step 1: Measure baseline
- [ ] Step 2: Bundle size
- [ ] Step 3: Rendering
- [ ] Step 4: Assets and DOM
- [ ] Step 5: Memory
- [ ] Step 6: Verify improvement
```

**Step 1 — Baseline.** Bundle analysis (`rollup-plugin-visualizer` / `vite-bundle-visualizer`). Devtools Performance recording: slow renders, long tasks, layout thrashing. Core Web Vitals: LCP, CLS, INP. `performance.mark/measure` for custom timings. Write the numbers down.

**Step 2 — Bundle.**

- Route-level code splitting: `React.lazy` + `Suspense` per React Router route.
- Heavy components (charts, editors, flow diagrams like `@xyflow/react`, color pickers) load on demand, not at page load.
- Named imports only; no `import * as`.
- Watch barrel files that re-export everything — they can defeat tree shaking.
- Audit dependencies (`depcheck`, `npx vite-bundle-visualizer`): duplicates, heavy libs with lighter alternatives, unused packages.

**Step 3 — Rendering.**

- First check the React Compiler is effective: run the compiler healthcheck / check for bailout diagnostics on hot components; fix Rules-of-React violations rather than sprinkling manual memo.
- State granularity: state close to consumers; zustand selectors narrow (`useStore(s => s.x)`); context values that change often split from stable ones.
- Re-render discipline (compiler or not):
  - Don't subscribe to state only read inside callbacks — read it fresh in the callback (deferred read) instead of re-rendering on every change.
  - Split combined hooks: a hook returning `{ a, b, c }` re-renders consumers that use only `a` when `b` changes.
  - Never define components inline inside render — they remount on every parent render.
  - Functional `setState(prev => ...)` when the update depends on previous state; lazy init `useState(() => expensive())`.
  - `useTransition`/`useDeferredValue` for expensive updates triggered by fast inputs (typing, dragging).
  - Refs for transient values that shouldn't render (timer IDs, previous values, mid-gesture coordinates).
- Stable keys: entity IDs, never array index on dynamic lists.
- Virtualize long lists (100+ items) with `@tanstack/react-virtual`.
- Don't store derived state — compute it.
- TanStack Query: tune `staleTime` to avoid refetch storms; use `select` to subscribe to slices of query data.

**Step 4 — Assets and DOM.**

- Images: modern formats, explicit `width`/`height` (prevents CLS), `loading="lazy"` below the fold.
- Animations: `transform`/`opacity` only (GPU-composited); `will-change` sparingly; batch DOM reads before writes.
- Fonts: `@fontsource-variable` already subsets; ensure `font-display: swap`; preload critical fonts.
- Third-party scripts (PostHog, analytics): async/defer, lazy-load non-essential embeds, budget third-party requests.
- Shallow DOM: remove wrapper divs that exist only for styling.

**Step 5 — Memory.** Every `addEventListener`/`setTimeout`/`setInterval`/subscription/WebSocket cleaned up in effect cleanup. `AbortController` for in-flight requests on unmount. Refs for non-rendering values (timer IDs, previous values).

**Step 6 — Verify.**

- Re-run bundle analysis; compare against baseline; flag chunks >200KB gzipped.
- Lighthouse: `npx lighthouse <URL> --output=json --output-path=./lighthouse-report.json --chrome-flags="--headless"`. Ask the user for the URL and thresholds; defaults: Performance ≥90, LCP ≤2.5s, INP ≤200ms, CLS ≤0.1.
- Quantify the delta ("main chunk 280KB → 140KB gzipped"). No measurable improvement → wrong bottleneck or regression; revert and re-profile.

## Memoization Decision Guide

| Situation | Action |
| --- | --- |
| "Component re-renders too much" | Check compiler bailout first; fix rule violations |
| Expensive computation feeding non-React consumer | `useMemo` acceptable |
| Compiler bailout you can't fix | Targeted manual memo, documented |
| Everything else | Leave it to the compiler |

## Bundle Red Flags

| Red flag | Action |
| --- | --- |
| Chunk >200KB gzipped | Code split |
| `moment.js`-class heavy lib | `date-fns` (already present) |
| `import * as` | Named imports |
| Full lodash | Per-method imports (`lodash.groupby` pattern) |
| Unpurged CSS | Tailwind 4 handles it — check custom CSS |
| Duplicate dependency versions | Resolve in lockfile |

## Checklist

```
- [ ] Baseline measured and documented
- [ ] Routes + heavy components lazy-loaded
- [ ] Compiler effective (no bailouts on hot paths)
- [ ] Narrow store/query subscriptions
- [ ] Long lists virtualized
- [ ] Images sized + lazy; animations on transform/opacity
- [ ] Effects clean up everything
- [ ] Post-optimization numbers vs baseline
```

## Related Skills

`implementing-frontend` · `reviewing-frontend` · `ensuring-accessibility`

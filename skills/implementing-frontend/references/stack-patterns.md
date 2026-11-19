# Stack Patterns — React 19 + Vite

Concrete patterns for React 19, Vite, React Compiler, Tailwind CSS 4, shadcn/ui + Radix, CVA, TanStack Query 5, Zustand 5, React Router 7, nuqs, react-error-boundary and Vitest.

**Apply a section only when the project uses that library.** Check `package.json` (and `components.json` for shadcn). A project on another router, store or styling system keeps its own patterns; these are not a migration target.

## React Compiler (only with `babel-plugin-react-compiler`)

- **Do NOT hand-write `useMemo`, `useCallback`, or `React.memo` by default.** The compiler auto-memoizes. Manual memoization is dead weight and can mask bugs.
- The compiler only works on code that follows the Rules of React. Keep `eslint-plugin-react-hooks` (v7 includes compiler-aware rules) clean — a violation makes the compiler bail out silently on that component.
- Legitimate remaining uses of `useMemo`: expensive computations whose result feeds a non-React consumer, or when profiling proves a compiler bailout you can't fix.
- Never mutate props, state, or values returned by hooks. Mutation breaks compiler assumptions.

## Tailwind 4 + design tokens

- Tokens live in CSS via `@theme` (CSS-first config) — colors, spacing, fonts as CSS variables. Map Figma values to existing `@theme` tokens; check `src/**/*.css` for the theme definition before assuming a token doesn't exist.
- Use semantic tokens (`bg-background`, `text-muted-foreground`, `border-input`) over raw palette values where the project defines them (shadcn convention).
- Class merging: always `cn()` (`clsx` + `tailwind-merge`) when combining conditional classes with props: `className={cn("flex gap-2", className)}`.
- Dark mode via `next-themes` — style with token variables, not `dark:` overrides of hardcoded colors.

## shadcn/ui + Radix + CVA

- Check `components/ui/` for an existing primitive before building one. Add missing shadcn components via the shadcn MCP if the project has it configured, otherwise the CLI (`shadcn add <name>` with the repo's package runner), then adapt — don't hand-roll dialogs, selects, dropdowns.
- Variants belong in CVA:

```tsx
const buttonVariants = cva("inline-flex items-center justify-center rounded-md", {
  variants: {
    variant: { default: "bg-primary text-primary-foreground", outline: "border border-input" },
    size: { sm: "h-8 px-3", md: "h-9 px-4" },
  },
  defaultVariants: { variant: "default", size: "md" },
});
```

- Compose with Radix primitives and `asChild`/`Slot` for polymorphism instead of `as` props.
- Radix handles focus management, ARIA, and keyboard interaction — do not re-implement or override it.

## API boundary (Zod-validated services)

- Entities are described by Zod schemas in the domain's `values/`; in-app types are inferred (`z.infer`), not hand-written.
- Services parse/validate ALL API responses against those schemas before hooks or components see the data, and translate API snake_case → in-app camelCase. API shapes never leak past the service layer.
- Endpoint typings come from generated OpenAPI schemas (`openapi-typescript`); hand-write API types only where generation falls short.

## TanStack Query 5

- Query options factories (co-located, typed):

```ts
export const userQueries = {
  detail: (id: string) =>
    queryOptions({ queryKey: ["users", id], queryFn: () => fetchUser(id) }),
};
```

- Data-dependent components handle `isPending` / `isError` / empty explicitly, or use `useSuspenseQuery` + `<Suspense>` + error boundary.
- Mutations invalidate affected queries in `onSuccess`. Optimistic updates only when UX demands it.
- Server state stays in the query cache. Never copy it into zustand or `useState` — select/derive instead (`select` option).
- **Never mutate a store from a `queryFn`** (retries/refetches make side effects there bugs). Mount-triggered flows: query + effect gated on `isFetchedAfterMount`. User-triggered flows: mutation with store writes in `onSuccess`.
- Mutation hooks own their toasts (`sonner` in `onSuccess`/`onError`, not in caller `.mutate()` callbacks) and take caller side effects (close dialog) as hook options. A mutation hook is a command — see `frontend-architecture`.
- Respect `@tanstack/eslint-plugin-query` findings.

## Zustand 5

- One store per domain concern, slices for growth. Select narrowly: `useStore(s => s.filter)` — never `const store = useStore()` in components.
- Updates via `immer` middleware where nested. Derived values via `zustand-computed`, not duplicated state.
- Only hooks/components touch stores; services never do. `getState()` only for fresh reads in event/async callbacks (stale-closure avoidance), never as default access. Full rules: `frontend-architecture`.

## Routing (React Router 7) + URL state

- Route-level code splitting with `React.lazy` per route.
- Shareable UI state (filters, tabs, search, pagination) belongs in the URL via `nuqs` parsers, not in stores.

## Error handling

- `react-error-boundary`: per-feature `<ErrorBoundary FallbackComponent={...} onReset={...}>`; pair with TanStack Query's `QueryErrorResetBoundary` for retryable fetch errors.
- Event handler / async errors are not caught by boundaries — handle explicitly, report to Sentry where meaningful.
- Toasts via `sonner` for transient failures; inline states for content areas.

## Dialogs and overlays

- If the project has a dialog controller/provider utility, use it instead of ad-hoc `useState(open)` wiring per dialog. Otherwise build on Radix `Dialog`/`vaul` primitives.

## Testing (Vitest + Testing Library)

- Test behavior through the DOM: `render` + `screen` + `userEvent`. Query by role/label, not test-id, unless unavoidable. Avoid testing implementation details.
- Tests colocated with the code (e.g. `dir/__tests__/format.test.ts` next to `dir/format.ts`) — follow the repo's placement convention.
- Test data via `fishery` factories colocated per domain (e.g. `<domain>/values/__fixtures__/<entity>.ts`, exported as `<entity>Factory`): `factory.build(overrides)` / `.buildList(n)`, `sequence` for unique ids, one trait factory per discriminated-union variant (never deep-merge across variants). Don't hand-write entity literals where a factory exists; add a factory rather than inlining. A factory's own test asserts its output parses against the entity's Zod schema.
- Use the repo's shared setup helpers (`renderWithProviders`/`renderHookWithProviders`, test QueryClient with retries off, store reset utilities, shared `vi.mock` modules) instead of per-file boilerplate.
- API mocking at the network boundary (MSW if present) or module boundary — not by mocking hooks.

## Completion gate

After any change: typecheck, lint, tests, build — using the repo's own scripts and package manager (check `package.json`/CLAUDE.md; don't assume npm vs bun).

## API layer

- Types generated from OpenAPI (`openapi-typescript`) — never hand-write types that the generator owns.
- `axios` instance with interceptors centralized; `envalid`-validated env access, no raw `import.meta.env` scattered around.

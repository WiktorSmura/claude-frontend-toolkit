---
name: frontend-architecture
description: Frontend codebase architecture — domain-driven module structure, layering (components/hooks/commands/services/stores), API boundary validation, cross-domain boundaries, and deciding where logic lives. Use when structuring new features or domains, deciding whether logic belongs in a component, hook, service, store action, or command, wiring API data into the app, or coordinating state across stores.
---

# Frontend Architecture

Where code lives and what may depend on what. These are strong defaults — when the project's CLAUDE.md or docs define their own conventions, those win; when they're silent, use this.

## Domain-Driven Structure

Divide the app into logical domains by functionality (`auth`, `search`, `library`, `graph`, `ui`, …), not by technical kind. Typical domain layout:

```
src/<domain>/
  api/         # endpoint calls (raw API types)
  values/      # Zod schemas + inferred types for domain entities
  services/    # pure: fetch-wiring, validation, translation
  hooks/       # query hooks, store hooks, domain-private coordination
  commands/    # complete user actions (the domain's stateful public surface)
  components/
```

- Shared "dumb" UI (heavy markup/styles, no domain logic) goes in a shared `ui` domain.
- Avoid circular dependencies between domains. Depend downward toward leaf domains (`ui`, `api`, persistence); don't reach back up. If the repo has boundary tooling (lint-enforced public interfaces, dependency graphs), respect it — exposing something new across a boundary is a deliberate, reviewable act, and keep that surface minimal.

## Data Flow: API → App

1. **Endpoints** live in the domain's `api/` — typed from generated OpenAPI schemas where available; hand-write API types only when the generator can't.
2. **Every entity the app uses is described by a Zod schema** in the domain's `values/`. In-app types are inferred from these schemas — no duplicate interfaces.
3. **Services parse and validate all API data against those schemas before any hook or component sees it.** Services also translate casing (API snake_case → in-app camelCase) and shapes. The API's format never leaks past the service layer.
4. **All fetching goes through the server-cache library** (TanStack Query or equivalent) via query hooks calling services.

## Layering: Where Does This Logic Go?

**Components stay thin.** No important logic, especially not coordinated store writes. Logic splits between services and hooks per the rules below.

**Services stay pure.** Endpoints, validation, translation, and store-free side effects (analytics capture, redirects). Services never import or call a store — that's what makes them safe to import across domains and trivially unit-testable. If a would-be service inherently needs store state, convert it to a hook that selects what it needs and returns the operation as a callback — don't thread store data as parameters at every call site, and don't reach into the store from the service.

**Store access happens only in hooks and components.** Stores never call other stores; store-to-store coordination lives in a hook that reads both and wires them together.

**Classify state-changing operations by how many stores they write:**

| Writes | Home |
| --- | --- |
| One store | A store action (the action IS the operation — don't wrap in a hook). Domain-private. |
| Two+ stores | A coordination hook. Domain-private. |
| A complete user action leaving the app consistent | A **command hook** in `commands/` — the only stateful surface other domains may call. |

**Completeness test for crossing a domain boundary:** if calling it alone can leave the app half-updated, it's granular → private. If it completes a named user action in a consistent state, it's a command → public. Cross-domain callers use commands or pure services — never another domain's store actions or internal hooks. Prefer growing the `commands/` surface over exposing granular hooks callers must sequence themselves.

## Server Cache × Stores

- **Never mutate a store from a `queryFn`.** Query functions retry and refetch; side effects there are bugs. Fetch in the queryFn, apply elsewhere:
  - **Auto-triggered on mount/route load** → query + effect: fetch with (dependent) queries, then an effect keyed on the fetched data applies it to stores, gated to run once per resolved payload.
  - **User-triggered** → command (mutation): `mutationFn` fetches, store writes go in `onSuccess`.
- Server state lives in the query cache — never mirror it into stores or `useState`; select/derive instead.
- Keep only data that must be global in global stores.

## Mutation Hook Conventions

- Success/error toasts belong inside the mutation hook's `onSuccess`/`onError` — not in caller `.mutate()` callbacks — so behavior stays consistent across callers.
- Caller-specific side effects (close a dialog) are accepted as **hook options**, not passed via `.mutate(params, {...})`.
- A mutation hook is a command → it lives in `commands/`.

## Store Access Idioms (Zustand-style)

- Read state and actions via selector: `useStore(s => s.collapseAll)`. Selecting an action is free — action references are stable.
- Avoid `getState()` as the default way to call actions: it's a non-reactive snapshot outside React's data flow. Its only legitimate use is reading/writing the freshest value inside an event handler or async callback to avoid a stale closure — and even then only in the React layer, never in services.

## Imports

Prefer direct imports over `index.ts` barrels. Barrel files obscure the dependency graph, hurt tree shaking, and invite import cycles. Exceptions: library entry points and app entry points. If the project governs boundaries another way (manifest + lint rule), follow that instead of barrels.

## Related Skills

`implementing-frontend` (component-level patterns) · `reviewing-frontend` (these rules as review criteria)

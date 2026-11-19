---
name: using-frontend-toolkit
description: Session bootstrap for frontend work — detects the project's stack and conventions, checks which capture MCPs are available, and installs the routing rules that dispatch to the right frontend skill and wire the review/verification gates into a superpowers brainstorm→spec→plan→implement→handoff workflow. Invoke at the start of a session that involves frontend implementation, review, or UI verification.
---

# Using the Frontend Toolkit

You are running a session that involves frontend work. Bootstrap now, then follow the routing
rules below for the rest of the session.

## Bootstrap (do this immediately, once)

1. **Read the project's conventions** — `CLAUDE.md` / `AGENTS.md` at repo root, and `docs/` index
   if present. These OVERRIDE every toolkit default. Note the package manager, the
   test/lint/typecheck/build commands, and any domain, layering, or documentation rules.
2. **Inventory the repo's own skills** — list `.claude/skills/*/SKILL.md` and read the frontmatter.
   Any repo skill that overlaps a toolkit skill **wins on mechanics**, and the toolkit skill
   contributes only its generic layer. The common cases:
   - a browser/dev-server skill → owns ports, server start, login, feature flags, state seeding,
     PR screenshots. `ui-verification` keeps only the evidence contract, comparison, and verdict.
   - a performance ruleset → apply alongside `optimizing-frontend`; repo rules win.
   - workflow skills (feature flags, releases, skill evolution) → follow them as-is; the toolkit
     has no opinion.
3. **Read `package.json`** — framework, router, server-cache lib, state lib, form lib, styling,
   test runner, linter, and whether the React Compiler is enabled. This decides which patterns apply.
4. **Check tooling** for UI verification: Figma MCP available? Claude in Chrome connected
   (preferred) or Playwright? Any component-library MCP (e.g. shadcn) worth using instead of
   hand-rolling primitives? Don't fix anything — just know.
5. **Report 3–5 lines**: detected stack, the repo's gate commands, which repo skills you're
   deferring to, the capture backend, and anything missing that would block verification later.
   Then proceed with the user's actual request.

Do not dump file contents or narrate each read. The point is a working mental model, not a report.

## Routing — which skill for which task

| The task is about | Load |
| --- | --- |
| Where new logic goes; domains; API→app data flow; store/service/command layering | `frontend-architecture` |
| Building or changing components, styling, Figma-to-code, design tokens | `implementing-frontend` |
| Keyboard, ARIA, contrast, screen readers, a11y audit | `ensuring-accessibility` |
| Slow renders, bundle size, Core Web Vitals, virtualization | `optimizing-frontend` |
| Reviewing a frontend diff or PR | `reviewing-frontend`, or dispatch the `frontend-reviewer` agent |
| "Does this match the design?" / a visual change needing proof | `ui-verification`, or dispatch the `ui-verifier` agent |

Load more than one when the task spans concerns — a design-backed feature with a form typically
needs `frontend-architecture` + `implementing-frontend`.

## Hard gates — do not skip these

- **Figma before code.** When a design reference exists for the task, read it through the Figma MCP
  before writing markup or styles. If the ticket doesn't carry a link, check the linked ADR/spec or
  ask once — then proceed without it rather than stalling.
- **A clean build is not UI verification.** Typecheck/lint/tests/build passing says nothing about
  visual correctness. Any change a user would notice visually gets browser evidence: design-diff
  against Figma when a node exists, otherwise a visual-check against named criteria. Both are real
  verification; skipping both is not.
- **Reading code is not verification either.** Verdicts require captured evidence — screenshot,
  computed styles, structure — not inspection of the source.
- **Never bypass auth.** If a login wall blocks capture, ask the user to log in manually in the
  connected browser and continue — never seed cookies, tokens, or roles.
- **The plugin's Stop hook backs this up:** if UI files were edited after the last browser
  screenshot, it blocks the first stop and asks for evidence (or a one-line "not user-visible").
- **Run the repo's completion gate** (its own typecheck/lint/test/build commands, its own package
  manager) after every change.
- **Project conventions win.** When the repo's CLAUDE.md, in-repo skills, or surrounding code
  disagree with a toolkit default, follow the repo and say so once. Never "correct" a codebase
  toward these skills' generic defaults.

## Superpowers workflow integration

| Phase | What this toolkit adds |
| --- | --- |
| Brainstorm | Nothing structural. Surface the Figma link early if the idea is UI-shaped. |
| Spec | Make visual/a11y criteria verifiable: "matches Figma node X at 1440px", "keyboard-operable, axe-clean" — not "looks right". |
| Plan / ticket | Per task, name the skills to load and the design link if one exists; add the verification gates to the acceptance criteria (see below). |
| Implement (subagent-driven) | See "Dispatching subagents" below — their context starts fresh. Review and verification are their own steps; both agents are read-only and report findings for the next step to fix. |
| Handoff | Include the review verdict and the last verification report; `.ui-verification/<slug>/` artifacts (expected vs actual per iteration) double as the PR's screenshots. |

**Extend acceptance criteria, don't replace them.** Most specs already end with the repo's command
gate. For a task that changes what a user sees, add the visual line next to it, in the spec's own
checkbox style:

```markdown
## Acceptance criteria
- [ ] <existing behavioral criteria …>
- [ ] Visual: <named, checkable claim — "the switch reads as one flush control at 1440px">,
      verified in the browser with captured evidence (design-diff vs <figma-node> if one exists).
- [ ] `<repo's typecheck>`, `<lint>`, `<test>`, `<build>` pass.
```

When you write or edit a spec/plan during this session, add that line to UI-touching tasks yourself
rather than waiting to be asked. Keep it to one line — a gate people paste is worth more than a
thorough one they skip.

## Dispatching subagents

A subagent's context window starts fresh: it receives **only the prompt string you pass**, not this
conversation, not the routing note the session started with, and not necessarily the project's
memory files. Whatever it needs must be in its prompt.

Nothing from this plugin reaches it automatically, so the parent owns all of it. When you
dispatch a subagent for frontend work, put these in the prompt:

- The skills it must load, by full name (`frontend-toolkit:implementing-frontend`, …).
- The design link, if the task has one.
- The repo's actual gate commands, and the instruction to run them before reporting done.
- What "done" means for this task, including the visual criteria if a user will see the change.
- The instruction to report honestly what it did **not** verify.

A subagent that reports "implemented and working" without having run anything is the normal failure
mode, not an unusual one. Ask for the evidence in the prompt and you get it; assume it and you don't.

## Related

`docs/USAGE.md` in this plugin covers installation and a copy-pasteable plan-task template.

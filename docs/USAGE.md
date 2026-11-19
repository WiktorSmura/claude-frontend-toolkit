# Using frontend-toolkit in a workflow

The [README](../README.md) covers installing it and each part. This page shows where it fits in a
plan-driven workflow, such as superpowers' brainstorm → spec → plan → implement → PR.

## Spec

Write visual criteria as checkable claims, next to the existing command gate:

```markdown
## Acceptance criteria
- [ ] <behavioural criteria …>
- [ ] Visual: <named claim, e.g. "the switch reads as one flush control at 1440px">, verified in
      the browser with captured evidence (design-diff vs <figma-node> if one exists).
- [ ] typecheck, lint, tests and build pass.
```

## Plan tasks

Name the skills and the design. Subagents start with nothing but their prompt, so a skill the
prompt doesn't name usually won't be loaded.

```markdown
### Task 3: Implement the settings panel
Skills: frontend-toolkit:implementing-frontend, frontend-toolkit:frontend-architecture
Design: <figma-url>

Done when:
- [ ] typecheck / lint / tests / build pass
- [ ] frontend-reviewer returns APPROVE
- [ ] ui-verifier returns PASS (design-diff) or CRITERIA MET (visual-check), and its
      "Not verified" line is empty or accepted
```

An orchestrator that hands whole tasks to other agents can name the bootstrap instead: "use
`frontend-toolkit:using-frontend-toolkit`". It tells the agent what to put in its own subagent
prompts.

## Before the PR

Run `frontend-reviewer` on the branch diff next to your general code review; they catch different
things. Fix its blocking items, then open the PR with the `ui-verifier` screenshots as evidence.

## Browser setup for ui-verifier

- Have the dev server running and the browser logged in before you dispatch it.
- Claude in Chrome gives it your real session. Playwright MCP works headless; log in through the
  repo's own browser skill, or once by hand.
- `ui-verifier` has no `tools:` allowlist on purpose, so it inherits your MCP tools. If you fork the
  plugin, don't add one, or it silently loses browser and Figma access.

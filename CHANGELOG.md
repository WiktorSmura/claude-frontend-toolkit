# Changelog

## 1.0.0: first public release

Measured over a month of real use in a production React codebase, after 0.5.0:

| Measure | Value |
| --- | --- |
| Sessions given the `SessionStart` routing note | 86 |
| …that loaded a toolkit skill | 4, all because the prompt named it |
| Subagents given the `SubagentStart` routing note | 203 (142 of them read-only Explore agents) |
| …that loaded a toolkit skill | **0** |
| `frontend-reviewer` / `ui-verifier` runs | 2 / 1, each found real issues |
| Slash commands run | 0 |

The model reads a "load X when Y" routing note and carries on without loading anything. What
worked was naming a skill in a prompt, dispatching an agent, and hooks that check results.

### Removed
- `SessionStart` and `SubagentStart` routing hooks.
- `/frontend`, `/frontend-review` and `/verify-ui` commands.
- `implementing-forms` and `writing-hooks` skills (never loaded).

### Added
- `Stop` hook `ui-evidence-gate.sh`: blocks the first stop after UI files are edited with no
  browser screenshot since, subagent transcripts included. Fires once per edit. Off in React
  Native, Expo and Electron projects, or with `FRONTEND_TOOLKIT_UI_GATE=off`. Self-check:
  `hooks/test-ui-evidence-gate.sh`.
- MIT license, plugin icon, marketplace renamed to `frontend-toolkit`.

### Changed
- Stack-specific advice (React Compiler, Radix/shadcn, Zustand, TanStack Query) now applies only
  when `package.json` shows the library.
- `ui-verifier`: a budget of about 10 screenshots per iteration, measuring computed styles first.
  One run had taken 64 browser actions to settle a single 20px-vs-24px question.

## 0.5.0: coverage and invented values

- **Coverage rule:** decide what to verify from the diff, not from what you were looking at. Bulk
  edits and shared-component changes land in components you never opened.
- **Coverage statement:** `ui-verification` reports carry `Covered:` and `Not verified:` lines.
- **Invented-value rule:** "the design system has no answer" doesn't mean you can pick a number. Match
  the nearest sibling control, or ask.
- Skill descriptions rewritten around symptoms ("typing stutters", "focus is lost") instead of topics.

## 0.4.0: subagents

- `SubagentStart` hook to reach subagents, whose context starts with only their prompt.
- Fixed `frontend-reviewer` being unable to load skills: a `tools` allowlist without `Skill`
  silently blocks them.

## 0.3.0: self-wiring

- `SessionStart` hook that injected a routing note in projects with a UI framework dependency.

## 0.2.x: overlays and layering

- `references/overlays-and-layering.md`: the `min-width: auto` overflow trap, stacking contexts and
  portals, and changing the layer that's actually wrong. These two bug classes caused most of the
  repeat visual fixes.

## 0.2.0: initial version

- Frontend subset of TheSoftwareHouse/copilot-collections, rewritten for Claude Code.

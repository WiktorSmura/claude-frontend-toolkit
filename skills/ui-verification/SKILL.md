---
name: ui-verification
description: Verify implemented UI in a real browser — capture screenshots, computed styles, and structure, then either diff against a Figma design or check against named visual criteria, and report severity-graded differences. Use after implementing or fixing UI, when asked "does this match the design", when a visual change needs proof before a PR, or when a fix needs before/after evidence.
---

# UI Verification

Compare what the app renders against what it should render, using real evidence. Code reading is
never verification — a clean build or passing types says nothing about visual correctness.

## Step 0: Who owns the browser?

**If the repo has its own browser/dev-server skill** (e.g. a `browser-testing` skill covering how
to start the dev server, pick a port, log in, toggle feature flags, seed app state, attach
screenshots to a PR) — **load it and let it own all of that.** It knows things this skill cannot:
the right port convention for worktrees, whether the dev script would kill another worktree's server,
where the debug/flag panel is, how PR screenshots get uploaded.

This skill then owns only what stays constant across repos: the evidence contract, the comparison
method, the tolerances, the verdict, and the fix loop. Do not re-derive capture mechanics that the
repo skill already specifies, and do not contradict it.

If no repo skill exists, capture with the Claude in Chrome MCP (preferred — real browser, the
user's real session) or Playwright (headless/CI fallback), and ask the user for the dev server URL
rather than guessing or starting a server.

## Pick a mode

| Mode | When | Verdict |
| --- | --- | --- |
| **Design-diff** | A Figma node (or exported design image) exists for this UI | PASS / FAIL against the design |
| **Visual-check** | No design reference — a spacing tweak, a styling fix, a bug repro, "does this look right" | Evidence + findings against named criteria; no design verdict |

Most real work is visual-check. Do not demand a Figma URL to proceed — that turns verification
into a blocker and gets it skipped. Ask for a design link once; if there isn't one, run
visual-check and say so in the report. Never label a visual-check result "PASS against Figma".

## Ground Rules (both modes)

- **Ask when anything is off.** Unreachable page, login wall you can't resolve, ambiguous target,
  failed capture — stop and ask. Never fabricate or proceed on partial evidence.
- **Pinned URL.** Get the exact full URL confirmed once (from the user or the repo's browser
  skill), then reuse it unchanged. Never infer a port, and never start, restart, or kill a dev
  server — other worktrees may share the machine.
- **Never bypass auth.** If a login wall blocks capture, ask the user to log in manually in the
  connected browser and continue — the session persists across reloads and ports. Never seed
  cookies, tokens, or roles. (Seeding *non-auth* app state — localStorage store keys, URL params —
  to reach a specific UI state is fine and usually faster than clicking through a flow.)
- **Design EXPECTED comes only from the Figma MCP.** Never screenshot figma.com in a browser as
  the reference.
- **Read console + network after the flow.** Runtime errors and failed requests are findings a
  screenshot won't show, and they're cheap to collect.

## Evidence Contract

Artifacts go in `.ui-verification/<slug>/` (gitignore it), `iteration-<N>/` per pass, with any
design export at the root as `figma-expected.png`. Collect:

1. **Screenshot** — viewport set to the design frame width (design-diff) or the relevant
   breakpoint (visual-check); page settled; saved to disk.
2. **Computed styles** — width/height/padding/margin/gap/font/color of the containers and controls
   in question, via JS evaluation in the page. Most commonly skipped, and the only way to catch
   sizing and spacing differences reliably. **Required in design-diff mode**; in visual-check,
   required whenever the change is about spacing, sizing, or layout.
3. **Structure snapshot** — accessibility/DOM tree for presence, order, and roles.

Design-diff without all three is invalid — report `VERIFICATION NOT RUN` rather than a verdict.

**Budget: about 10 screenshots per iteration.** Measure first: one JS evaluation that returns every
computed value you need usually settles the question. Screenshot only the states the verdict rests
on, and confirm a click landed with the structure snapshot, not another screenshot. When the
question is one dimension, measure it and stop.
These same screenshots are what a PR needs; if the repo defines a PR-screenshot workflow, reuse
them there instead of shooting new ones.

## Design-diff mode

1. Resolve the Figma node (fileKey + nodeId) via the Figma MCP, export it to
   `figma-expected.png`, and extract specs: hierarchy, layout, spacing, frame width, typography,
   colors, radii, variants/states. Reuse an existing export if the node is unchanged. Genuine
   export failure (MCP down, node unresolvable) → `VERIFICATION NOT RUN` + blocker.
2. Capture the evidence contract above at the design's frame width.
3. Compare with multimodal image comparison **plus** computed styles — never pixel-diff alone.

| Category | Check | Tolerance |
| --- | --- | --- |
| Structure | Element presence, hierarchy, order | Exact — mismatch is CRITICAL |
| Layout | Direction, alignment, position | Exact — CRITICAL |
| Dimensions | Widths, heights, spacing, gaps | ±2px; beyond = CRITICAL |
| Typography | Family, size, weight, line-height | Size/weight exact; rendering minor |
| Color | Fills, borders, text | Exact token match; antialiasing exempt |
| States | Hover, focus, disabled, error, empty | Per design; missing = WARNING |
| Content | Text, data values | May vary by env/seed — clarification gate |

**PASS gate:** never PASS while a structure, layout, or >2px dimension difference remains.
**Content gate:** if everything structural passes and only content/data values differ (seed data,
locale, user state), ask whether those should match the design — that's a question, not a defect.

## Visual-check mode

1. **Name the criteria first.** Turn the request into checkable statements before capturing — from
   the ticket's acceptance criteria, the bug report, or the user's words: "the switch reads as one
   flush control", "no gap above the subtitle", "unavailable panes look disabled, not hidden".
   Verification without stated criteria degenerates into "looks fine to me".
2. Capture the evidence contract (computed styles whenever spacing/sizing is the point).
3. For a fix, capture **before/after**: same URL, same viewport, same state — the before pass on
   the unfixed build (or from the prior iteration's artifacts), so the difference is demonstrable
   rather than asserted.
4. Walk the interaction states the change touches (hover, focus, disabled, loading, empty) and the
   breakpoints it claims to support.
5. **Capture overlays in their open state.** A closed-state screenshot proves nothing about a
   dialog, popover, panel, scrim, or tour step — open it, and capture computed styles for both the
   scrim and the surface plus the layer behind them. Overflow bugs need hostile content too: check
   a long unbreakable string, not the happy-path label.
6. **For a fix, confirm you changed the responsible layer.** Diff the computed styles of the element
   you edited *and* its neighbours before/after. If the page background moved when the scrim was
   the complaint, the fix is in the wrong place — that's how a visual fix ships, reads fine in one
   state, and gets reverted a commit later.
5. Report each criterion as MET / NOT MET / UNCLEAR with the artifact and computed value that
   shows it, plus anything else you noticed (console errors, layout shift, clipped text).

## Coverage: verify everything you changed

Decide what to capture from **the diff**, not from what you were investigating. A change to a shared
primitive, or a bulk edit (`perl -pi`, `sed -i`, folder-wide find-and-replace), lands in components
you never opened — and those are where the regression will be, because you weren't watching them.

Before capturing, list the affected kinds: each control type, each variant, each consumer surface.
Check one instance of each. If that list is too long to cover, say so and name what you skipped —
an honest gap is useful; an unstated one reads as a clean bill of health.

## Report

```
## UI Verification: <target> — <design-diff | visual-check> — iteration <N>
Verdict: PASS | FAIL | CRITERIA MET | CRITERIA NOT MET | VERIFICATION NOT RUN
Evidence: <artifact paths, console/network notes>
Covered: <the kinds/variants actually captured>
Not verified: <affected kinds not captured, and why> — required; write "nothing" only if the diff
              genuinely touches one surface and you captured it.

### Findings
[CRITICAL] <category>: expected <X>, got <Y> (<artifact/computed value>) → fix: <action>
[WARNING] ...

### Blockers (only when NOT RUN)
<what's missing and exactly what the caller or user should do>
```

State the mode in every report. A visual-check report must never imply a design comparison happened.

## Fix Loop

After fixes, re-capture into `iteration-<N+1>/` and re-verify — never reuse stale captures, never
accept a single FAIL as final. Iterate until PASS/criteria met or 5 completed iterations; then
summarize what's left and ask: continue, stop as ESCALATED, or custom instruction. Fix differences
you can *name* (spacing, weight, color, radius, size); when only unnameable rendering noise
remains, report it instead of chasing pixels.

## States That Hide Bugs

Design-diff or visual-check, these are the states that pass a naive screenshot and fail in
production. Cover the ones the change plausibly touches:

- Overlays **open** (dialog, popover, dropdown, tour step) — and the layer behind them.
- Hostile content: a very long unbreakable string, an empty list, one item, hundreds of items.
- Both themes, if the app has them — a color fix made in one theme often breaks or vanishes in the other.
- The narrow breakpoint the design claims to support, not just the width you happened to open.

## What Belongs Here vs a Unit Test

Browser-verify what jsdom can't see: canvas/chart output, virtualized scrolling, drag & drop,
popover/dialog layering, real API payloads, visual fidelity. Store, service, and formatting logic
belongs in unit tests — faster, and it stays as a regression guard. A browser check proves today's
build; a test prevents tomorrow's regression. Prefer the test when both would work.

## Related Skills

`implementing-frontend` (the patterns being verified) · `ensuring-accessibility` (interpreting the
structure snapshot) · `reviewing-frontend` (code-level review — complementary, not a substitute)

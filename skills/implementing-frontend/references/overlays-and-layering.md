# Overlays, Layering, and Overflow

The two bug classes that cause the most visual rework: content escaping its container, and the
wrong layer being styled. Both are cheap to prevent and expensive to chase after merge.

## The min-width:auto overflow trap

Flex and grid children default to `min-width: auto`, which means **they refuse to shrink below
their content's intrinsic size**. Long unbreakable content — a series name, an ID, a URL, a code
token — then pushes the track wider than its container, and the whole panel or dialog overflows.
`overflow-hidden` on the parent doesn't fix it; it just clips the symptom.

Fixes, in order of preference:

| Situation | Fix |
| --- | --- |
| Grid container with a single content column | `grid-cols-[minmax(0,1fr)]` |
| Grid track that must be shrinkable | `minmax(0, 1fr)` instead of `1fr` |
| Flex child that must shrink | `min-w-0` (and `min-h-0` for the vertical axis) |
| Text that should ellipsize | `truncate` **plus** `min-w-0` on every flex ancestor between it and the constraint |

Rules of thumb:

- Any container with a `max-w-*` or fixed width whose children are dynamic text is a candidate.
  Dialogs, popovers, side panels, table cells, list rows, and toasts are where this shows up.
- `truncate` that "doesn't work" is almost always a missing `min-w-0` on an ancestor, not a
  problem with the truncation itself.
- Test with hostile content, not the happy path: a 120-character word, a long CJK string, an
  unbroken ID. If the layout only survives short labels, it isn't done.

## Layering: change the layer that's wrong

When something looks too dark, too light, or in front of the wrong thing, identify the responsible
layer **before** editing. The failure mode is fixing a symptom on the nearest available element —
darkening the app shell to simulate a darker modal scrim, raising a z-index until a thing appears —
which looks right in one state and wrong in every other, then gets reverted.

Diagnose from computed styles with the overlay *open*:

1. Which element actually paints the pixels you dislike — the scrim, the panel surface, or the page
   background behind both?
2. Which stacking context does each live in? Portalled overlay content is **not** a descendant of
   the component that opened it, so app-shell styling doesn't reach it and vice versa.
3. Only then change that element.

Specifics worth knowing:

- **Radix (and most headless libs) portal overlay + content to the body as siblings.** The scrim is
  its own element: style the scrim to change the scrim. Styling the page background to make a modal
  feel darker changes the app in every non-modal state too.
- **`transform`, `filter`, `backdrop-filter`, `will-change`, `contain`, and `perspective` create
  containing blocks / stacking contexts.** A `fixed` child inside one positions against that
  ancestor, not the viewport — a common cause of "my dropdown is anchored to the wrong place" and
  "my sticky header stopped sticking".
- **Own the z-index scale centrally.** A handful of named tiers (content < sticky < panel < scrim <
  modal < popover < toast) beats ad-hoc numbers. An arbitrary `z-[9999]` is a smell: it wins today
  and breaks the next overlay.
- **Don't nest scrims.** Two overlapping semi-transparent scrims compound to a darker result than
  either design specifies; one scrim owned by one layer is the invariant.
- **Dark mode multiplies these mistakes.** A change that reads correctly in one theme can be
  invisible or muddy in the other — check both before calling it done.

## Verify overlays in their open state

Layering and overflow bugs are invisible in a closed-state screenshot. When verifying:

- Capture the state where the thing is actually shown: dialog open, popover open, panel expanded,
  tour step visible.
- Capture computed styles for both the scrim and the surface, not just the surface.
- Check the layer *behind* the overlay too — that's where "I darkened the wrong element" shows up.
- For a fix, capture before/after in the same state, and confirm the element you changed is the one
  that moved.

## Consistency across siblings

Cards, sections, and rows that sit next to each other should derive their size, padding, and
typography from one shared component or token set. When each is styled independently they drift —
subtly at first, then visibly enough to need a follow-up "make them all the same size" commit. If
two sections look alike by coincidence rather than by construction, that's a refactor worth doing
while you're there.

## Product tours and onboarding overlays

Tour libraries anchor to DOM elements by selector, which makes them fragile in ways normal UI isn't:

- The target may not be mounted (lazy route, collapsed panel, feature-flagged element). Guard each
  step and skip gracefully rather than pointing at nothing.
- Tour popovers compete with dialogs and toasts for the top layer — put them in the z-index scale
  deliberately.
- "Seen" state is persisted state: version it, and make sure a returning user isn't re-tour'd by a
  storage migration.
- Verify a tour by stepping through it in the browser; a passing test says almost nothing about
  whether the highlight lands on the right element.

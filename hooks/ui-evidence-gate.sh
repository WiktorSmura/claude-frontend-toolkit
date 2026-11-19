#!/usr/bin/env bash
# Stop hook: when this session (or its subagents) edited UI files and no browser screenshot
# was taken after the last such edit, block the stop once and ask for evidence.
#
# - Fires at most once per edit: the timestamp of the last UI edit it blocked on is stored, so a
#   reply like "not user-visible, skipping" ends the turn on the next stop.
# - Off when FRONTEND_TOOLKIT_UI_GATE=off, and in React Native / Expo / Electron projects.
# - Reads the session transcript with grep only (no jq/python), matching keys independently of
#   their order. If the transcript can't be read it stays silent rather than guessing.

set -uo pipefail

[ "${FRONTEND_TOOLKIT_UI_GATE:-on}" = "off" ] && exit 0

input="$(cat)"
grep -qE '"stop_hook_active" *: *true' <<<"$input" && exit 0

root="${CLAUDE_PROJECT_DIR:-$PWD}"
grep -qsE '"(react-native|expo|electron)" *:' "$root/package.json" && exit 0

transcript="$(sed -n 's/.*"transcript_path" *: *"\([^"]*\)".*/\1/p' <<<"$input")"
session="$(sed -n 's/.*"session_id" *: *"\([^"]*\)".*/\1/p' <<<"$input")"
[ -f "$transcript" ] || exit 0

files=("$transcript")
for f in "${transcript%.jsonl}"/subagents/*.jsonl; do [ -f "$f" ] && files+=("$f"); done

# Latest ISO timestamp (sorts lexically) among transcript lines passing the given grep filters.
last_ts() { cat "${files[@]}" | "$@" | grep -oE '"timestamp" *: *"[^"]+"' | sort | tail -1 | sed 's/.*"\([^"]*\)"$/\1/'; }

ui_edit() {
  grep -E '"name" *: *"(Edit|Write|MultiEdit)"' \
    | grep -E '"file_path" *: *"[^"]*\.(tsx|jsx|vue|svelte|astro|css|scss)"' \
    | grep -vE '"file_path" *: *"[^"]*(\.(test|spec|stories)\.[a-z]+|/__tests__/[^"]*)"'
}
# Any tool whose name or action says screenshot (Claude in Chrome, Playwright, Puppeteer,
# chrome-devtools, preview tools), or a shell command that takes one. Design-tool exports
# (Figma) are the expected side, not evidence.
screenshot() {
  grep -iE '"name" *: *"[^"]*screenshot[^"]*"|"action" *: *"screenshot"|"command" *: *"[^"]*screenshot' \
    | grep -viE '"name" *: *"[^"]*figma[^"]*screenshot'
}

edit_ts="$(last_ts ui_edit)"
[ -n "$edit_ts" ] || exit 0

shot_ts="$(last_ts screenshot)"
[[ -n "$shot_ts" && "$shot_ts" > "$edit_ts" ]] && exit 0

state="${TMPDIR:-/tmp}/frontend-toolkit-ui-gate-${session:-unknown}"
[ "$(cat "$state" 2>/dev/null)" = "$edit_ts" ] && exit 0
printf '%s' "$edit_ts" >"$state"

cat <<'EOF'
{"decision":"block","reason":"[frontend-toolkit] UI files were edited after the last browser screenshot, and a clean build is not UI verification. Check the changed UI in a browser (the repo's own browser skill if it has one, or the ui-verifier agent), capture overlays open, and say what you verified and what you did not. If no user could see this change, say so in one line and stop: this gate fires once per edit."}
EOF
exit 0

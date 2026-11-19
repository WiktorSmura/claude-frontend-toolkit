#!/usr/bin/env bash
# Self-check for ui-evidence-gate.sh: bash hooks/test-ui-evidence-gate.sh
set -u
here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export TMPDIR="$tmp" CLAUDE_PROJECT_DIR="$tmp/app"
unset FRONTEND_TOOLKIT_UI_GATE
mkdir -p "$tmp/app" "$tmp/s/subagents"
pkg() { echo "{\"dependencies\":{$1}}" >"$tmp/app/package.json"; }
pkg '"react":"19","react-dom":"19"'

T1=2026-01-01T10:00:00Z; T2=2026-01-01T11:00:00Z
tool() { echo "{\"timestamp\":\"$1\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"$2\",\"input\":$3}]}}"; }
edit() { tool "$1" Edit "{\"file_path\":\"$2\"}"; }
chrome() { tool "$1" mcp__claude-in-chrome__computer '{"action":"screenshot"}'; }

run() { echo "{\"session_id\":\"x\",\"transcript_path\":\"$tmp/s.jsonl\",\"stop_hook_active\":${1:-false}}" | bash "$here/ui-evidence-gate.sh"; }
fail=0
# name | main transcript | subagent transcript | stop_hook_active | expect
check() {
  rm -f "$tmp"/frontend-toolkit-ui-gate-*
  printf '%b' "$2" >"$tmp/s.jsonl"; printf '%b' "$3" >"$tmp/s/subagents/a.jsonl"
  got=allow; run "$4" | grep -q '"decision":"block"' && got=block
  [ "$got" = "$5" ] && echo "ok   $1" || { echo "FAIL $1: want $5, got $got"; fail=1; }
}
check "tsx edit, no screenshot"          "$(edit $T1 /a/B.tsx)\n" ""                "false" block
check "chrome screenshot after edit"     "$(edit $T1 /a/B.tsx)\n$(chrome $T2)\n" "" "false" allow
check "screenshot before edit"           "$(chrome $T1)\n$(edit $T2 /a/B.tsx)\n" "" "false" block
check "screenshot in subagent"           "$(edit $T1 /a/B.tsx)\n" "$(chrome $T2)\n" "false" allow
check "edit in subagent only"            "" "$(edit $T1 /a/b.css)\n"                "false" block
check "test file only"                   "$(edit $T1 /a/B.test.tsx)\n" ""           "false" allow
check "file under __tests__"             "$(edit $T1 /a/__tests__/x.tsx)\n" ""      "false" allow
check "non-UI file"                      "$(edit $T1 /a/b.ts)\n" ""                 "false" allow
check "already continuing from the hook" "$(edit $T1 /a/B.tsx)\n" ""                "true"  allow
check "figma export is not evidence"     "$(edit $T1 /a/B.tsx)\n$(tool $T2 mcp__figma__get_screenshot '{}')\n" "" "false" block
for t in mcp__playwright__browser_take_screenshot mcp__chrome-devtools__take_screenshot mcp__puppeteer__puppeteer_screenshot; do
  check "evidence: $t"                   "$(edit $T1 /a/B.tsx)\n$(tool $T2 $t '{}')\n" "" "false" allow
done
check "evidence: playwright from Bash"   "$(edit $T1 /a/B.tsx)\n$(tool $T2 Bash '{"command":"npx playwright screenshot http://localhost:5173 a.png"}')\n" "" "false" allow
check "keys in another order, spaced"    "{\"message\": {\"content\": [{\"input\": {\"file_path\": \"/a/B.vue\"}, \"name\": \"Write\"}]}, \"timestamp\": \"$T1\"}\n" "" "false" block

printf '%s\n' "$(edit $T1 /a/B.tsx)" >"$tmp/s.jsonl"; : >"$tmp/s/subagents/a.jsonl"; rm -f "$tmp"/frontend-toolkit-ui-gate-*
run >/dev/null
[ -z "$(run)" ] && echo "ok   second stop on the same edit passes" || { echo "FAIL repeat block"; fail=1; }

rm -f "$tmp"/frontend-toolkit-ui-gate-*
[ -z "$(FRONTEND_TOOLKIT_UI_GATE=off run)" ] && echo "ok   FRONTEND_TOOLKIT_UI_GATE=off" || { echo "FAIL opt-out"; fail=1; }

pkg '"react":"19","react-native":"0.80"'
check "react-native project"             "$(edit $T1 /a/B.tsx)\n" ""                "false" allow
rm "$tmp/app/package.json"
check "no package.json (monorepo root)"  "$(edit $T1 /a/B.tsx)\n" ""                "false" block
exit $fail

#!/usr/bin/env bash
# Self-check for pr-review-gate.sh and review-marker.sh: bash hooks/test-pr-review-gate.sh
set -u
here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
g() { git -C "$tmp/repo" -c user.email=t@t -c user.name=t "$@" >/dev/null 2>&1; }

git init -q --bare "$tmp/origin.git"
git init -q -b main "$tmp/repo"
mkdir -p "$tmp/repo/src/__tests__"
echo 'export const a = 1' >"$tmp/repo/src/a.ts"; g add -A; g commit -m init
g remote add origin "$tmp/origin.git"; g push -u origin main; g remote set-head origin main
g checkout -b feat/x

# Each case starts from a clean feat/x on main with the given files committed.
commit() { g reset -q --hard main; for f in "$@"; do echo "x" >"$tmp/repo/$f"; done; g add -A; g commit -m change; }
gate() { # $1 = command, $2 = session cwd
  printf '{"cwd":"%s","tool_name":"Bash","tool_input":{"command":"%s"}}' "${2:-$tmp/repo}" "$1" \
    | if [ "${GATE:-on}" = unset ]; then env -u FRONTEND_TOOLKIT_PR_GATE bash "$here/pr-review-gate.sh"; \
      else FRONTEND_TOOLKIT_PR_GATE="${GATE:-on}" bash "$here/pr-review-gate.sh"; fi 2>/dev/null; echo $?; }
review() { printf '{"cwd":"%s","agent_type":"frontend-toolkit:frontend-reviewer"}' "$tmp/repo" | bash "$here/review-marker.sh"; }
unreview() { rm -rf "$tmp/repo/.git/frontend-toolkit-reviewed"; }

fail=0
check() { [ "$2" = "$3" ] && echo "ok   $1" || { echo "FAIL $1: want exit $3, got $2"; fail=1; }; }

commit src/Card.tsx; unreview
check "UI change, no review: blocks"           "$(gate 'gh pr create --fill')" 2
check "gate off by default (variable unset)"   "$(GATE=unset gate 'gh pr create --fill')" 0
check "other commands pass"                    "$(gate 'git push -u origin HEAD')" 0
check "one-off skip in the command"            "$(gate 'FRONTEND_TOOLKIT_PR_GATE=off gh pr create --fill')" 0
check "leading cd into the repo is followed"   "$(gate "cd $tmp/repo && gh pr create --fill" /)" 2
review
check "after frontend-reviewer ran: passes"    "$(gate 'gh pr create --fill')" 0
check "marker survives a later commit"         "$(g commit --allow-empty -m more; gate 'gh pr create')" 0
commit src/a.test.tsx src/__tests__/b.tsx src/c.ts; unreview
check "only tests and non-UI files: passes"    "$(gate 'gh pr create --fill')" 0
commit src/styles.css; unreview
check "css counts as UI"                       "$(gate 'gh pr create --fill')" 2
check "not a git repo: passes"                 "$(gate 'gh pr create' "$tmp")" 0
exit $fail

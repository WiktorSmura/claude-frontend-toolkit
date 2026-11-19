#!/usr/bin/env bash
# PreToolUse hook (Bash), opt-in with FRONTEND_TOOLKIT_PR_GATE=on: blocks `gh pr create` on a
# branch whose commits change UI files until the frontend-reviewer agent has run on it
# (review-marker.sh writes the marker). The marker records that a review ran, not that it passed.
#
# A reminder, not a lock: it reads the command text, so `gh pr create` hidden in a script is not
# seen. It follows a leading `cd <dir> &&`. Anything it can't determine (no git, no base branch)
# lets the command through. A command containing FRONTEND_TOOLKIT_PR_GATE=off skips it once.

set -uo pipefail
[ "${FRONTEND_TOOLKIT_PR_GATE:-off}" = "on" ] || exit 0

input="$(cat)"
grep -qE 'gh[[:space:]]+pr[[:space:]]+create' <<<"$input" || exit 0
grep -q 'FRONTEND_TOOLKIT_PR_GATE=off' <<<"$input" && exit 0

cwd="$(sed -n 's/.*"cwd" *: *"\([^"]*\)".*/\1/p' <<<"$input")"
cwd="${cwd:-$PWD}"
# Follow a leading `cd <dir>` in the command (unquoted or double-quoted path).
cd_dir="$(sed -nE 's/.*"command" *: *"cd +(\\"([^\\]*)\\"|([^ ;&|"]+)).*/\2\3/p' <<<"$input")"
if [ -n "$cd_dir" ]; then
  case "$cd_dir" in
    /*) cwd="$cd_dir" ;;
    "~"*) cwd="$HOME${cd_dir#\~}" ;;
    *) cwd="$cwd/$cd_dir" ;;
  esac
fi

git_dir="$(git -C "$cwd" rev-parse --absolute-git-dir 2>/dev/null)" || exit 0
branch="$(git -C "$cwd" symbolic-ref --short -q HEAD)" || exit 0
[ -f "$git_dir/frontend-toolkit-reviewed/${branch//\//%2F}" ] && exit 0

base=""
for ref in origin/HEAD origin/main origin/master; do
  base="$(git -C "$cwd" merge-base HEAD "$ref" 2>/dev/null)" && break
done
[ -n "$base" ] || exit 0

ui_files="$(git -C "$cwd" diff --name-only "$base" HEAD \
  | grep -E '\.(tsx|jsx|vue|svelte|astro|css|scss)$' \
  | grep -vE '(\.(test|spec|stories)\.[a-z]+$|(^|/)__tests__/)')"
[ -n "$ui_files" ] || exit 0

cat >&2 <<EOF
[frontend-toolkit] Branch '$branch' changes UI files and no frontend review has run on it yet.
Dispatch the frontend-toolkit:frontend-reviewer agent on the branch diff, fix its blocking items,
then open the PR. To skip once, put FRONTEND_TOOLKIT_PR_GATE=off in front of the command.
EOF
exit 2

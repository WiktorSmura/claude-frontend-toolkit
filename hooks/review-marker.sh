#!/usr/bin/env bash
# SubagentStop hook (matcher: frontend-reviewer): records that a frontend review ran on the
# current branch, for pr-review-gate.sh. The marker lives in the git dir, so it is per
# worktree, never committed, and survives later commits: fixing findings needs no second review.

set -uo pipefail
input="$(cat)"
cwd="$(sed -n 's/.*"cwd" *: *"\([^"]*\)".*/\1/p' <<<"$input")"
cwd="${cwd:-$PWD}"

git_dir="$(git -C "$cwd" rev-parse --absolute-git-dir 2>/dev/null)" || exit 0
branch="$(git -C "$cwd" symbolic-ref --short -q HEAD)" || exit 0

mkdir -p "$git_dir/frontend-toolkit-reviewed"
git -C "$cwd" rev-parse HEAD >"$git_dir/frontend-toolkit-reviewed/${branch//\//%2F}"
exit 0

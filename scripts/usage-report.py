#!/usr/bin/env python3
"""Measure whether frontend-toolkit changes behaviour, from your Claude Code transcripts.

    python3 scripts/usage-report.py [--since YYYY-MM-DD] [--projects-dir DIR] [--json]

Reads ~/.claude/projects/*/<session>.jsonl and each session's subagents/ transcripts, locally
and read-only. For every session it works out whether UI files were edited, whether a browser
screenshot came after the last UI edit (the same test the Stop gate applies), how often either
gate blocked, and which toolkit agents and skills ran. Standard library only.
"""
import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

PLUGIN = "frontend-toolkit"
# Keep in step with hooks/ui-evidence-gate.sh.
UI_FILE = re.compile(r"\.(tsx|jsx|vue|svelte|astro|css|scss)$")
NOT_UI = re.compile(r"(\.(test|spec|stories)\.[a-z]+$|/__tests__/)")
STOP_GATE_TEXT = "[frontend-toolkit] UI files were edited"
PR_GATE_TEXT = "[frontend-toolkit] Branch '"
# Collapses worktree checkouts onto their repo: .../worktrees/<repo>/<branch>, .../<repo>/.claude/worktrees/<name>.
WORKTREE = re.compile(r"/worktrees/([^/]+)/[^/]+$|/([^/]+)/\.claude/worktrees/[^/]+$")


def is_screenshot(name, tool_input):
    if "figma" in name.lower():
        return False
    if "screenshot" in name.lower() or tool_input.get("action") == "screenshot":
        return True
    return name == "Bash" and "screenshot" in str(tool_input.get("command", ""))


def text_of(content):
    if isinstance(content, list):
        return "".join(c.get("text", "") for c in content if isinstance(c, dict))
    return content if isinstance(content, str) else ""


def is_hook_message(text, prefix, marker):
    return text.lstrip().startswith(prefix) and marker in text


def project_of(cwd):
    m = WORKTREE.search(cwd)
    return (m.group(1) or m.group(2)) if m else (Path(cwd).name or cwd)


def scan_session(paths):
    s = {"cwd": "", "start": "", "last_ui_edit": "", "last_shot": "", "stop_blocks": 0,
         "pr_blocks": 0, "agents": Counter(), "skills": Counter()}
    for path in paths:
        with path.open(errors="ignore") as f:
            lines = f.readlines()
        for line in lines:
            try:
                d = json.loads(line)
            except ValueError:
                continue
            ts = d.get("timestamp", "")
            if ts and (not s["start"] or ts < s["start"]):
                s["start"] = ts
            s["cwd"] = s["cwd"] or d.get("cwd", "")
            content = (d.get("message") or {}).get("content")
            # The harness records Stop hook feedback as a meta user message; text that merely
            # quotes it (tool output, a normal prompt) is not a block.
            if d.get("type") == "user" and d.get("isMeta") and isinstance(content, str):
                s["stop_blocks"] += is_hook_message(content, "Stop hook feedback", STOP_GATE_TEXT)
            if not isinstance(content, list):
                continue
            for block in content:
                if not isinstance(block, dict):
                    continue
                if block.get("type") == "tool_result":
                    s["pr_blocks"] += is_hook_message(text_of(block.get("content")), "PreToolUse:Bash hook error", PR_GATE_TEXT)
                if block.get("type") != "tool_use":
                    continue
                name, inp = block.get("name", ""), block.get("input") or {}
                file_path = str(inp.get("file_path", ""))
                if name in ("Edit", "Write", "MultiEdit") and UI_FILE.search(file_path) and not NOT_UI.search(file_path):
                    s["last_ui_edit"] = max(s["last_ui_edit"], ts)
                if is_screenshot(name, inp):
                    s["last_shot"] = max(s["last_shot"], ts)
                if name in ("Agent", "Task") and str(inp.get("subagent_type", "")).startswith(PLUGIN + ":"):
                    s["agents"][inp["subagent_type"].split(":", 1)[1]] += 1
                if name == "Skill" and str(inp.get("skill", "")).startswith(PLUGIN + ":"):
                    s["skills"][inp["skill"].split(":", 1)[1]] += 1
    s["edited_ui"] = bool(s["last_ui_edit"])
    s["evidence"] = s["edited_ui"] and s["last_shot"] > s["last_ui_edit"]
    return s


def sessions(projects_dir):
    for main in sorted(projects_dir.glob("*/*.jsonl")):
        yield [main, *sorted(main.with_suffix("").glob("subagents/*.jsonl"))]


def report(projects_dir, since=""):
    rows = [s for s in map(scan_session, sessions(projects_dir)) if s["start"] >= since]
    by_project = defaultdict(Counter)
    total, agents, skills = Counter(), Counter(), Counter()
    for s in rows:
        p = by_project[project_of(s["cwd"])]
        for c in (total, p):
            c["sessions"] += 1
            c["ui_sessions"] += s["edited_ui"]
            c["with_evidence"] += s["evidence"]
            c["stop_blocks"] += s["stop_blocks"]
            c["pr_blocks"] += s["pr_blocks"]
            c["agent_runs"] += sum(s["agents"].values())
        agents.update(s["agents"])
        skills.update(s["skills"])
    starts = sorted(s["start"][:10] for s in rows)
    return {"from": starts[0] if starts else None, "to": starts[-1] if starts else None,
            "totals": dict(total), "agents": dict(agents), "skills": dict(skills),
            "projects": {k: dict(v) for k, v in sorted(by_project.items(), key=lambda kv: -kv[1]["ui_sessions"]) if v["ui_sessions"]}}


def pct(part, whole):
    return f"{part} ({round(100 * part / whole)}%)" if whole else str(part)


def render(r):
    t = Counter(r["totals"])
    lines = [f"frontend-toolkit usage, {r['from']} to {r['to']}: {t['sessions']} sessions", "",
             f"Sessions that edited UI files            {t['ui_sessions']}",
             f"  ...with a screenshot after the last edit  {pct(t['with_evidence'], t['ui_sessions'])}",
             f"Stop gate blocks                         {t['stop_blocks']}",
             f"PR gate blocks                           {t['pr_blocks']}"]
    lines += [f"Agent runs: {name:<28} {n}" for name, n in sorted(r["agents"].items(), key=lambda kv: -kv[1])] or ["Agent runs                               0"]
    lines += [f"Skill loads: {name:<27} {n}" for name, n in sorted(r["skills"].items(), key=lambda kv: -kv[1])] or ["Skill loads                              0"]
    if r["projects"]:
        lines += ["", "By project (sessions that edited UI):"]
        for name, p in r["projects"].items():
            p = Counter(p)
            lines.append(f"  {name:<24} {p['ui_sessions']:>4} UI sessions, {pct(p['with_evidence'], p['ui_sessions'])} with evidence, "
                         f"{p['agent_runs']} agent runs, {p['stop_blocks']} stop / {p['pr_blocks']} PR gate blocks")
    return "\n".join(lines)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--since", default="", help="only sessions starting on or after this date (YYYY-MM-DD)")
    ap.add_argument("--projects-dir", type=Path, default=Path.home() / ".claude" / "projects")
    ap.add_argument("--json", action="store_true", help="print the raw numbers as JSON")
    args = ap.parse_args(argv)
    if not args.projects_dir.is_dir():
        sys.exit(f"no transcripts at {args.projects_dir}")
    r = report(args.projects_dir, args.since)
    print(json.dumps(r, indent=2) if args.json else render(r))


if __name__ == "__main__":
    main()

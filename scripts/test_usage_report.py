"""Self-check for usage-report.py: python3 -m unittest discover -s scripts"""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("usage_report", Path(__file__).with_name("usage-report.py"))
usage_report = importlib.util.module_from_spec(spec)
spec.loader.exec_module(usage_report)


def tool(ts, name, inp):
    return {"timestamp": ts, "type": "assistant",
            "message": {"content": [{"type": "tool_use", "name": name, "input": inp}]}}


def edit(ts, path):
    return tool(ts, "Edit", {"file_path": path})


def shot(ts, name="mcp__claude-in-chrome__computer"):
    return tool(ts, name, {"action": "screenshot"})


def stop_feedback(ts, text):
    return {"timestamp": ts, "type": "user", "isMeta": True, "message": {"content": "Stop hook feedback:\n" + text}}


def tool_result(ts, text):
    return {"timestamp": ts, "type": "user", "message": {"content": [{"type": "tool_result", "content": text}]}}


def write(path, lines, cwd):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(json.dumps({**line, "cwd": cwd}) + "\n" for line in lines))


class UsageReportTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        wt = "/home/u/.herdr/worktrees/shop/feat-a"
        # Edits UI, gets blocked once, screenshots after, runs the reviewer and loads a skill.
        write(self.dir / "p1/a.jsonl", [
            edit("2026-02-01T10:00:00Z", "/x/src/Card.tsx"),
            stop_feedback("2026-02-01T10:01:00Z", "[frontend-toolkit] UI files were edited after ..."),
            shot("2026-02-01T10:02:00Z"),
            tool("2026-02-01T10:03:00Z", "Agent", {"subagent_type": "frontend-toolkit:frontend-reviewer"}),
            tool("2026-02-01T10:04:00Z", "Skill", {"skill": "frontend-toolkit:implementing-frontend"}),
        ], wt)
        # A subagent edits CSS; the only "screenshot" afterwards is a Figma export; the PR gate blocks.
        write(self.dir / "p1/b.jsonl", [
            tool_result("2026-02-02T10:05:00Z", "PreToolUse:Bash hook error: [frontend-toolkit] Branch 'x' changes UI files"),
        ], "/home/u/.herdr/worktrees/shop/feat-b")
        write(self.dir / "p1/b/subagents/agent-1.jsonl", [
            edit("2026-02-02T10:00:00Z", "/x/src/app.css"),
            shot("2026-02-02T10:01:00Z", "mcp__figma__get_screenshot"),
        ], "/home/u/.herdr/worktrees/shop/feat-b")
        # Tool output that merely quotes the gate messages is not a block.
        write(self.dir / "p2/f.jsonl", [
            tool_result("2026-02-03T12:00:00Z", "log: Stop hook feedback:\n[frontend-toolkit] UI files were edited"),
            tool_result("2026-02-03T12:01:00Z", "grep: PreToolUse:Bash hook error: [frontend-toolkit] Branch 'x'"),
            {"timestamp": "2026-02-03T12:02:00Z", "type": "user",
             "message": {"content": "Stop hook feedback:\n[frontend-toolkit] UI files were edited (pasted)"}},
        ], "/home/u/projects/api")
        # Only a test file and a .ts file change: not a UI session.
        write(self.dir / "p2/c.jsonl", [
            edit("2026-02-03T10:00:00Z", "/y/src/__tests__/Card.tsx"),
            edit("2026-02-03T10:01:00Z", "/y/src/a.test.tsx"),
            edit("2026-02-03T10:02:00Z", "/y/src/util.ts"),
        ], "/home/u/projects/api")
        # Screenshot first, UI edit after it: no evidence for the final state.
        write(self.dir / "p2/e.jsonl", [
            shot("2026-02-03T11:00:00Z"),
            edit("2026-02-03T11:01:00Z", "/y/src/Late.tsx"),
        ], "/home/u/projects/api")
        # Older than --since in the filtered run.
        write(self.dir / "p2/d.jsonl", [edit("2025-12-01T10:00:00Z", "/y/src/Old.tsx")], "/home/u/projects/api")

    def tearDown(self):
        self.tmp.cleanup()

    def test_counts_sessions_evidence_gates_and_toolkit_use(self):
        r = usage_report.report(self.dir, since="2026-01-01")
        self.assertEqual(r["totals"], {"sessions": 5, "ui_sessions": 3, "with_evidence": 1,
                                       "stop_blocks": 1, "pr_blocks": 1, "agent_runs": 1})
        self.assertEqual(r["agents"], {"frontend-reviewer": 1})
        self.assertEqual(r["skills"], {"implementing-frontend": 1})
        self.assertEqual((r["from"], r["to"]), ("2026-02-01", "2026-02-03"))

    def test_groups_worktrees_by_repo_and_orders_projects_by_ui_sessions(self):
        r = usage_report.report(self.dir, since="2026-01-01")
        self.assertEqual(list(r["projects"]), ["shop", "api"])
        self.assertEqual(r["projects"]["shop"]["ui_sessions"], 2)

    def test_since_includes_older_sessions_when_omitted(self):
        self.assertEqual(usage_report.report(self.dir)["totals"]["ui_sessions"], 4)

    def test_screenshot_detection(self):
        cases = [
            ("mcp__playwright__browser_take_screenshot", {}, True),
            ("mcp__claude-in-chrome__computer", {"action": "screenshot"}, True),
            ("mcp__claude-in-chrome__computer", {"action": "left_click"}, False),
            ("Bash", {"command": "npx playwright screenshot http://localhost:5173 a.png"}, True),
            ("mcp__claude_ai_Figma__get_screenshot", {}, False),
        ]
        for name, inp, want in cases:
            with self.subTest(name=name, inp=inp):
                self.assertIs(usage_report.is_screenshot(name, inp), want)

    def test_renders_a_readable_summary(self):
        text = usage_report.render(usage_report.report(self.dir, since="2026-01-01"))
        self.assertIn("...with a screenshot after the last edit  1 (33%)", text)
        self.assertIn("shop", text)


if __name__ == "__main__":
    unittest.main()

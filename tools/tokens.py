#!/usr/bin/env python3
"""Token usage of one build session, read from the harness transcripts.

    tokens.py <launch-run.txt> <project-dir> [<until-iso>]

Counts every model request (main agent and subagents) of the harness whose working directory is
the project, from the start time in launch-run.txt up to <until-iso> (default: now). Prints one JSON
object with the runs.csv fields tok_input, tok_cache_read, tok_cache_write, tok_output, turns and
minutes. Claude Code and Codex are supported; Antigravity stores its transcripts in a binary format,
so its tokens are entered by hand.
"""
import glob
import json
import os
import sys
from datetime import datetime, timezone


def ts(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


def inside(cwd, project):
    """True if cwd is the project folder or lies in it (not a sibling such as <project>-t2)."""
    cwd = str(cwd or "")
    return cwd == project or cwd.startswith(project.rstrip(os.sep) + os.sep)


def claude(project, since, until):
    root = os.path.join(os.environ.get("CLAUDE_CONFIG_DIR", os.path.expanduser("~/.claude")), "projects")
    usage, last = {}, None
    for path in glob.glob(os.path.join(root, "**", "*.jsonl"), recursive=True):
        for line in open(path, errors="replace"):
            try:
                e = json.loads(line)
            except ValueError:
                continue
            if e.get("type") != "assistant" or not inside(e.get("cwd"), project):
                continue
            t = ts(e["timestamp"])
            if not (since <= t <= until):
                continue
            m = e.get("message", {})
            u = m.get("usage")
            if not u:
                continue
            usage[m.get("id") or e.get("requestId") or id(e)] = u   # streamed blocks repeat the usage
            last = max(last or t, t)
    tot = {"tok_input": 0, "tok_cache_read": 0, "tok_cache_write": 0, "tok_output": 0}
    for u in usage.values():
        tot["tok_input"] += u.get("input_tokens", 0)
        tot["tok_cache_read"] += u.get("cache_read_input_tokens", 0)
        tot["tok_cache_write"] += u.get("cache_creation_input_tokens", 0)
        tot["tok_output"] += u.get("output_tokens", 0)
    tot["turns"] = len(usage)
    return tot, last


def codex(project, since, until):
    root = os.path.join(os.environ.get("CODEX_HOME", os.path.expanduser("~/.codex")), "sessions")
    tot = {"tok_input": 0, "tok_cache_read": 0, "tok_cache_write": 0, "tok_output": 0, "turns": 0}
    last = None
    for path in glob.glob(os.path.join(root, "**", "rollout-*.jsonl"), recursive=True):
        meta, final, turns, end = None, None, 0, None
        for line in open(path, errors="replace"):
            try:
                e = json.loads(line)
            except ValueError:
                continue
            p = e.get("payload", {})
            if e.get("type") == "session_meta":
                meta = p
            elif e.get("type") == "event_msg" and p.get("type") == "token_count" and p.get("info"):
                t = ts(e["timestamp"])
                if since <= t <= until:
                    final, end = p["info"]["total_token_usage"], t
                    turns += 1
        if not meta or not inside(meta.get("cwd"), project) or not final:
            continue
        cached = final.get("cached_input_tokens", 0)          # part of input_tokens at OpenAI
        tot["tok_input"] += final.get("input_tokens", 0) - cached
        tot["tok_cache_read"] += cached
        tot["tok_cache_write"] += final.get("cache_write_input_tokens", 0)
        tot["tok_output"] += final.get("output_tokens", 0)
        tot["turns"] += turns
        last = max(last or end, end)
    return tot, last


def main():
    launch, project = sys.argv[1], os.path.realpath(sys.argv[2])
    info = dict(l.split(": ", 1) for l in open(launch).read().splitlines() if ": " in l)
    since = ts(info["started_utc"])
    until = ts(sys.argv[3]) if len(sys.argv) > 3 else datetime.now(timezone.utc)
    if info["harness"] == "claude":
        tot, last = claude(project, since, until)
    elif info["harness"] == "codex":
        tot, last = codex(project, since, until)
    else:
        print("{}")
        return
    if not last or not tot.get("turns"):
        print("{}")          # no transcript of this session on this machine: report nothing, not zeros
        return
    tot["minutes"] = round((last - since).total_seconds() / 60, 1)
    print(json.dumps(tot))


if __name__ == "__main__":
    main()

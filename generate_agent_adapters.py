#!/usr/bin/env python3
"""
generate_agent_adapters.py — fan out Claude Code skills (.claude/skills/<name>/SKILL.md)
into equivalent instruction files for other AI coding agents:

  - Cursor:   .cursor/rules/<name>.mdc
  - Copilot:  .github/instructions/<name>.instructions.md
  - Gemini:   GEMINI.md   (one shared file, marked sections per skill)
  - Codex:    AGENTS.md   (one shared file, marked sections per skill)

Claude Code itself needs no adapter — it reads .claude/skills/*/SKILL.md directly.

The shared files (GEMINI.md, AGENTS.md) may already contain hand-written project
content, so each skill's section is wrapped in markers and only that section is
replaced on re-run — everything else in the file is left alone.

Usage:
    python generate_agent_adapters.py --project-root /path/to/project
    python generate_agent_adapters.py --project-root /path/to/project --skills-dir /path/to/.claude/skills
    python generate_agent_adapters.py --project-root /path/to/project --targets cursor,copilot
"""

import argparse
import os
import re
import sys

MARKER_START = "<!-- dev-assistant:skill:{name}:start -->"
MARKER_END = "<!-- dev-assistant:skill:{name}:end -->"

ALL_TARGETS = ["cursor", "copilot", "gemini", "codex"]


def parse_skill_md(path: str):
    with open(path, encoding="utf-8") as f:
        text = f.read()

    m = re.match(r"^---\s*\n(.*?\n)---\s*\n(.*)$", text, re.DOTALL)
    if not m:
        return None

    frontmatter, body = m.group(1), m.group(2).strip()
    name_m = re.search(r"^name:\s*(.+)$", frontmatter, re.MULTILINE)
    desc_m = re.search(r"^description:\s*(.+)$", frontmatter, re.MULTILINE)
    if not name_m:
        return None

    name = name_m.group(1).strip()
    description = desc_m.group(1).strip() if desc_m else ""
    return {"name": name, "description": description, "body": body}


def find_skills(skills_dir: str):
    skills = []
    if not os.path.isdir(skills_dir):
        return skills
    for entry in sorted(os.listdir(skills_dir)):
        skill_md = os.path.join(skills_dir, entry, "SKILL.md")
        if os.path.isfile(skill_md):
            parsed = parse_skill_md(skill_md)
            if parsed:
                skills.append(parsed)
    return skills


def write_cursor_rule(project_root: str, skill: dict):
    out_dir = os.path.join(project_root, ".cursor", "rules")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, f"{skill['name']}.mdc")
    
    always_apply = "true" if skill["name"] in ["regression-guard", "live-context-verifier", "senior-engineer-mindset"] else "false"
    
    content = (
        "---\n"
        f"description: {skill['description']}\n"
        f"alwaysApply: {always_apply}\n"
        "---\n\n"
        f"{skill['body']}\n"
    )
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(content)
    return out_path


def write_copilot_instructions(project_root: str, skill: dict):
    out_dir = os.path.join(project_root, ".github", "instructions")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, f"{skill['name']}.instructions.md")
    content = (
        "---\n"
        'applyTo: "**"\n'
        f"description: {skill['description']}\n"
        "---\n\n"
        f"{skill['body']}\n"
    )
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(content)
    return out_path


def upsert_marked_section(file_path: str, skill: dict):
    """Insert or replace this skill's marked section in a shared instructions file."""
    start = MARKER_START.format(name=skill["name"])
    end = MARKER_END.format(name=skill["name"])
    section = f"{start}\n## {skill['name']}\n\n{skill['description']}\n\n{skill['body']}\n{end}\n"

    existing = ""
    if os.path.isfile(file_path):
        with open(file_path, encoding="utf-8") as f:
            existing = f.read()

    pattern = re.compile(
        re.escape(start) + r".*?" + re.escape(end) + r"\n?", re.DOTALL
    )
    if pattern.search(existing):
        updated = pattern.sub(lambda _m: section, existing)
    elif existing:
        sep = "\n" if existing.endswith("\n") else "\n\n"
        updated = existing + sep + section
    else:
        updated = section

    with open(file_path, "w", encoding="utf-8") as f:
        f.write(updated)
    return file_path


def main():
    ap = argparse.ArgumentParser(description="Fan out Claude Code skills to other AI agent formats")
    ap.add_argument("--project-root", required=True, help="Target project root")
    ap.add_argument("--skills-dir", default=None, help="Defaults to <project-root>/.claude/skills")
    ap.add_argument(
        "--targets",
        default=",".join(ALL_TARGETS),
        help=f"Comma-separated subset of: {','.join(ALL_TARGETS)}",
    )
    ap.add_argument("--only", default=None, help="Comma-separated skill names to process (default: all found)")
    args = ap.parse_args()

    project_root = os.path.abspath(args.project_root)
    skills_dir = args.skills_dir or os.path.join(project_root, ".claude", "skills")
    targets = [t.strip().lower() for t in args.targets.split(",") if t.strip()]
    unknown = set(targets) - set(ALL_TARGETS)
    if unknown:
        print(f"  ERROR: unknown target(s): {', '.join(unknown)} (supported: {', '.join(ALL_TARGETS)})")
        sys.exit(1)

    skills = find_skills(skills_dir)
    if args.only:
        wanted = {s.strip() for s in args.only.split(",") if s.strip()}
        skills = [s for s in skills if s["name"] in wanted]

    if not skills:
        print(f"  No skills found under {skills_dir}")
        sys.exit(1)

    gemini_path = os.path.join(project_root, "GEMINI.md")
    agents_path = os.path.join(project_root, "AGENTS.md")

    for skill in skills:
        name = skill["name"]
        if "cursor" in targets:
            p = write_cursor_rule(project_root, skill)
            print(f"  [cursor]  {name} -> {p}")
        if "copilot" in targets:
            p = write_copilot_instructions(project_root, skill)
            print(f"  [copilot] {name} -> {p}")
        if "gemini" in targets:
            upsert_marked_section(gemini_path, skill)
            print(f"  [gemini]  {name} -> {gemini_path} (section updated)")
        if "codex" in targets:
            upsert_marked_section(agents_path, skill)
            print(f"  [codex]   {name} -> {agents_path} (section updated)")

    print(f"\n  Done. {len(skills)} skill(s) fanned out to: {', '.join(targets)}")


if __name__ == "__main__":
    main()

---
name: context-loader
description: Load this project's real architecture rules, tech stack, and closest reference ("golden") module before starting any coding task. Use at the start of essentially every feature, bug fix, or refactor — before touching a backend service, a frontend component, or the database — since skipping this is how features end up inconsistent with everything else in the codebase. Auto-detects context from a connected dev-assistant config.json, or falls back to CLAUDE.md/AGENTS.md/architecture docs already in the project. Especially useful right before context-loader's companions pattern-clone and code-review-quality.
---

# Context Loader

Running this before writing code is what makes the difference between a feature that looks like it belongs in this codebase and one that looks bolted on. Do it even for small tasks — a "quick fix" that ignores the existing pattern is how inconsistency creeps in one commit at a time.

## Step 1: Load Project Context

Try these sources in order and stop at the first one that gives real signal:

1. **A connected dev-assistant config.** dev-assistant installs live as a sibling folder next to the project they're connected to. Look up to two directories above this project's root for a `config.json` that either sits inside a folder named `dev-assistant`, or whose own `projectRoot` field (path-normalized) matches this project's root. If found, read `techStack`, `backendPattern`, `frontendPattern`, `apiPattern`, `architectureRules`, `goldenModuleSimple`, `goldenModuleWizard`, and `existingFeatures` — treat this as authoritative.
2. **Project docs**, if no config.json turns up. Read whichever exist: `CLAUDE.md`, `AGENTS.md`, `ARCHITECTURE_RULES.md`, `.agents/project-context/*.md`, `docs/architecture.md`.
3. **The code itself**, always, regardless of source 1 or 2 — config files and docs go stale, and a golden module named in a config from three months ago may have been refactored since. Skim the actual file before trusting it's still a good reference.

## Step 2: Identify the Task Type

Classify the task: backend CRUD, frontend page, API integration, DB change, bug fix, refactor, or report/export. This determines which reference module is relevant in Step 3.

## Step 3: Find the Closest Reference Module

- If `goldenModuleSimple` / `goldenModuleWizard` are set in the loaded config, start there.
- Otherwise, scan `existingFeatures` (or just the repo) for the feature most similar in shape to the one you're about to build — same category of CRUD, same kind of multi-step form, same kind of read-only report.
- If nothing is close enough to be useful, say so rather than forcing a fit — better to build from first principles with the architecture rules in hand than to clone a poor match.

## Step 4: Extract the Actual Pattern

Read the reference module's real files and note, from what you observe (not from general framework conventions):

- Folder structure and naming conventions
- Request/response or DTO shape
- The service/data-access pattern actually used (don't assume a specific ORM or layering style — read what's there)
- Validation approach
- Error-handling convention
- Anything the loaded architecture rules explicitly call out (e.g. "one database context only", "columns use snake_case")

## Output Before Coding

Produce this summary before writing any code — it's cheap insurance against building the wrong thing:

```text
- Task understood:
- Task type:
- Closest reference module (or "none close enough"):
- Pattern to follow:
- Files to create:
- Files to update:
- Files that must NOT change:
- Existing helpers/services to reuse:
- Risks or confirmation needed:
```

## Consistency Check Before Final Response

- [ ] Pattern matches the reference module (or architecture rules, if no module was close enough)
- [ ] No duplicate helpers, services, or DTOs created
- [ ] No unused code introduced
- [ ] No unrelated files touched
- [ ] Build/test impact considered

## Related Skills

- `pattern-clone` — clone the reference module's structure once the plan above is settled
- `code-review-quality` — run before calling the task done

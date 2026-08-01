---
applyTo: "**"
description: Enforce context freshness before touching any code. Verifies graphify node hierarchy and dependent modules to prevent working on stale or partial context.
---

# Live Context Verifier

Run this skill before writing any code to ensure you are operating on the 100% current state of the codebase.

## Step 1: Verify Graph Freshness

- Ensure the `graphify` knowledge graph (`graph.json` or equivalent) is up to date.
- If you suspect the codebase has changed since the graph was last built, trigger a graph update (e.g., `graphify .`) or instruct the user to do so.
- NEVER assume the state of a file without reading its latest version.

## Step 2: Inspect Dependent Modules

- Before creating a new service, utility, or UI component, query the graph to see if a similar module already exists.
- Locate shared utility imports (e.g., `utils/`, `helpers/`, `shared/`) and read their contents to avoid writing duplicate logic.

## Step 3: Generate Pre-Change Context Matrix

Before executing edits, summarize your context:
- Target files to edit: [List files and read their latest contents]
- Existing utilities to leverage: [List found utilities]
- Modules dependent on target files: [List from graph]

If you cannot confidently fill out this matrix, STOP and read more files until you have the full picture.

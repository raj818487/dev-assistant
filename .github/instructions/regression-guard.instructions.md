---
applyTo: "**"
description: Run this graphify-powered regression gate before completing any code change to ensure existing functionality and caller contracts remain 100% unbroken.
---

# Regression Guard

Run this before finalizing any coding task to ensure zero regressions in old working code.

## Step 1: Graphify Dependency Scan

Before modifying an existing file or module, use `graphify` query commands (or equivalent graph tools in this project) to map:
- **Incoming Callers**: Which files, functions, or modules call the code you are about to change?
- **Outgoing Dependencies**: What utilities or external services does this code rely on?

## Step 2: Signature & Contract Safety

Based on the graph from Step 1, verify that your proposed changes maintain backward compatibility:
- Do NOT change the signature, parameters, or return types of public methods or API endpoints if they have upstream callers.
- If a signature MUST change, you MUST also locate and update all upstream callers in the graph.
- Do NOT make breaking schema changes to database models or DTOs without providing a safe migration path.

## Step 3: Run Baseline Tests

Before concluding your task, identify and run the existing unit or integration test suite for the modified module.
- The tests MUST pass.
- If no tests exist, verify manually or write a regression test for the existing behavior before modifying it.

## Step 4: Post-Edit Graph Audit

After your edits are made, verify that no caller edges were severed or corrupted.
- Does the modified code still seamlessly integrate with its existing callers?
- Did you accidentally overwrite or delete unrelated logic in the file? (Verify via `git diff`).

## Step 5: Rollback Guard

If ANY existing functionality, test, or downstream caller breaks due to your changes:
- Stop immediately.
- Revert the changes.
- Rethink the approach to ensure the new feature is added additively (e.g., via extension or new endpoints) rather than destructively modifying working code.

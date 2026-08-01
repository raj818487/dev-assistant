---
applyTo: "**"
description: Run this quality and duplicate-prevention gate before calling any coding task finished — a new API, a CRUD feature, a UI component, a refactor, or a bug fix. Checks for scope creep, duplicate logic, dead code, and violations of this project's own architecture rules (not generic assumptions about frameworks), plus basic security and performance issues. Use as the last step before saying a task is done, the same way you'd run a linter or self-review before opening a PR — for any language or stack.
---

# Code Review Quality

Run this before the final response for any coding-related task, regardless of stack.

## Step 1: Scope Review

- Did the change touch only the files the task actually required?
- Did it avoid unrelated refactoring bundled into the same change?
- Did it avoid generating extra files nobody asked for?
- Does it follow the existing pattern for this kind of change (see `context-loader` / `pattern-clone`)?

**Fail if:** unrelated files changed, a new pattern was introduced without a real need for it, or code was generated outside the task's actual scope.

## Step 2: Duplicate Code Review

Search for existing logic before approving new logic. Common places duplication hides, in any stack:

- Pagination, sorting, filtering, search
- Timezone handling, current-user/context resolution
- Audit trail, soft delete, "already in use" checks
- Response mapping, exception handling
- File generation, null handling, validation

**Decision:** if an existing utility already does this, reuse it. If the same logic now appears 3+ times, flag it for extraction rather than silently adding a fourth copy. If a near-duplicate DTO/type/method already exists, remove the new one.

## Step 3: Unwanted Code Review

Flag or remove:
- Unused imports, variables, private methods/functions
- Unused types/DTOs/request-response shapes
- Commented-out code, dead code, stray debug output (`console.log`, `print`, `Console.WriteLine`, or whatever this language's equivalent is)
- Hardcoded IDs or TODOs that weren't explicitly requested
- Empty catch/except blocks that silently swallow errors

## Step 4: Architecture Review — Against *This Project's* Rules

This is the step that must not be generic. Pull up whatever was loaded in `context-loader` (a connected dev-assistant `config.json`, or `CLAUDE.md`/`AGENTS.md`/architecture docs) and check the actual implementation against it — not against a different stack's conventions or a generic best-practice checklist:

- Does it match this project's stated backend/frontend layering (whatever that is — thin controllers with a service layer, MVC, hexagonal, whatever this project actually uses)?
- Does it violate any explicit architecture rule (e.g. "no second database context," "no repository layer," "state must go through signals/store," or whatever this project's rules say)?
- Does it follow this project's actual naming, folder, and file-organization conventions, as observed in the reference module?

If no architecture rules were found at all, say so explicitly in the output rather than silently applying a generic assumption — a review that's grounded in nothing is worse than one that admits its limits.

## Step 5: Security & Performance

- Are authorization checks present on anything that needs them, matching how the rest of the project enforces access control?
- Is user input validated?
- For paginated queries: is the count taken without first materializing the full result set?
- Any obvious N+1 query pattern, or a query pulling more columns/rows than the feature needs?

## Step 6: Output Format

```text
## Code Review Result

### Status
Pass / Needs Changes

### Issues Found
1. [High/Medium/Low] Issue title
   - File:
   - Problem:
   - Suggested Fix:

### Duplicate Code Check
Passed / Failed — notes

### Unwanted Code Check
Passed / Failed — notes

### Architecture Check
Passed / Failed / No project rules found to check against — notes

### Security Check
Passed / Failed — notes

### Performance Check
Passed / Failed — notes

### Final Recommendation
Ready to merge / Fix required before merge
```

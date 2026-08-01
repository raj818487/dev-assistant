---
name: code-reduction-audit
description: Audit the entire repository for over-engineering using graphify and search tools, outputting a master list of technical debt to delete.
---

# Code Reduction Audit

Run this skill when asked to audit the whole repo (not just a single diff) for over-engineering.

## Step 1: Scan the Codebase
Use `graphify` (e.g. `graphify .`) and `grep_search` to map out the repository. Look for:
- "Wrapper" components that just wrap native HTML elements (e.g. `DateInput` wrapping `<input type="date">`).
- Utility files duplicating standard library functions (e.g. a custom padding or mapping function).
- Code that violates the "Lazy Dev" 7-step ladder.

## Step 2: The 7-Step "Lazy Dev" Ladder
For the suspicious code blocks you found, ask:
1. Does this need to exist? (YAGNI)
2. Is there something else in this codebase that already does this? 
3. Does the standard library do this?
4. Is there a native platform feature? 
5. Does an installed dependency already do this?
6. Can this be written in one line?

## Step 3: Create the Technical Debt Ledger
Output a document listing everything you found. For each item, provide:
- The file path.
- The over-engineered code.
- The one-line or native replacement.
- An estimation of how many lines of code can be deleted by making this change.

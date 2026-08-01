---
name: code-reduction-review
description: Review the current diff or working files for over-engineering and provide a delete-list of code that can be replaced by one-liners or native features.
---

# Code Reduction Review

Run this skill to review the current diff (or the code you just wrote) for over-engineering.

## Step 1: Analyze Current Changes
Look at the files you have modified or created.

## Step 2: Apply the "Lazy Dev" Ladder
For every function, component, or logic block you added, ask:
1. Does this need to exist? (YAGNI)
2. Is there something in this codebase that already does this? (Use `grep_search` or `graphify` to check).
3. Does the standard library do this?
4. Is there a native platform feature? (e.g., HTML5 native inputs instead of heavy React wrappers).
5. Does an installed dependency already do this?
6. Can this be written in one line?

## Step 3: Output the Delete-List
If you find over-engineering, output a harsh "Delete-List". Tell the user exactly what to delete and replace it with the simpler, one-line equivalent.

If the code is already perfectly minimal, say: "Code is minimal. Nothing to delete."

<!-- dev-assistant:skill:code-review-quality:start -->
## code-review-quality

Run this quality and duplicate-prevention gate before calling any coding task finished — a new API, a CRUD feature, a UI component, a refactor, or a bug fix. Checks for scope creep, duplicate logic, dead code, and violations of this project's own architecture rules (not generic assumptions about frameworks), plus basic security and performance issues. Use as the last step before saying a task is done, the same way you'd run a linter or self-review before opening a PR — for any language or stack.

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
<!-- dev-assistant:skill:code-review-quality:end -->

<!-- dev-assistant:skill:context-loader:start -->
## context-loader

Load this project's real architecture rules, tech stack, and closest reference ("golden") module before starting any coding task. Use at the start of essentially every feature, bug fix, or refactor — before touching a backend service, a frontend component, or the database — since skipping this is how features end up inconsistent with everything else in the codebase. Auto-detects context from a connected dev-assistant config.json, or falls back to CLAUDE.md/AGENTS.md/architecture docs already in the project. Especially useful right before context-loader's companions pattern-clone and code-review-quality.

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
<!-- dev-assistant:skill:context-loader:end -->

<!-- dev-assistant:skill:db-design:start -->
## db-design

Design database schema changes, queries, indexes, and migration/rollback plans for any new table, column, relationship, or data-access change — for whatever database and migration tool this project actually uses (PostgreSQL, MySQL, SQL Server, MongoDB, EF Core migrations, Prisma, Django, Rails, Alembic, Flyway, raw SQL, or anything else). Use whenever a feature needs new persisted data, a schema change, a new query shape, or an index/performance decision. Grounds every decision in this project's real architecture rules and existing schema conventions instead of generic textbook database advice.

# DB Design

Schema mistakes are expensive to undo once data is in production — this skill exists to catch them on paper first.

## Step 1: Learn This Project's Real DB Setup

Don't assume a stack. Work it out:

1. Check a connected dev-assistant `config.json` (see `context-loader`) for `techStack` and any DB-related lines in `architectureRules` (e.g. "one database context only", "columns use snake_case", specific naming or constraint conventions).
2. Find the actual migration/schema mechanism by looking for what exists: an EF Core `Migrations/` folder, Prisma's `schema.prisma`, Django `migrations/`, Rails `db/migrate/`, Alembic `versions/`, Flyway/Liquibase SQL files, or hand-written SQL. Whatever's already there is what you use — don't introduce a second migration system.
3. Read 2-3 recent, representative migrations or schema definitions to learn the project's real conventions: naming style, how soft-delete/status is represented, how foreign keys are typically scoped (cascade vs. restrict), how indexes are named.

## Step 2: Design the Change

1. Identify schema, query, index, and data-access impact of the requested feature.
2. Match the naming and status/soft-delete conventions you found in Step 1 — don't invent a new one for this feature alone.
3. Decide FK behavior (cascade/restrict/set-null) consistent with how similar relationships are already handled in this project.
4. Identify any data boundary or permission-leakage risk (e.g. a query that could return another tenant's/branch's rows without a filter).
5. Note performance implications — new indexes needed, queries that will scan large tables, N+1 risks from the access pattern this feature implies.

## Step 3: Plan the Migration Safely

- No schema change ships without a documented rollback path — know how to undo it before you apply it.
- After generating a migration, inspect what it actually contains before running it. A migration meant to add a new table should contain a create-table operation — if it only touches unrelated constraints or looks like it's dropping/renaming something you didn't intend, stop and investigate before applying it. This applies regardless of which migration tool generated it.
- Never hand-edit an auto-generated migration snapshot/lock file directly — regenerate it through the tool.
- If the project's migration tool has a "pending model changes" or "diff" check, run it before handoff and confirm it reports clean.

## Required Output

- `docs/specs/<feature>-db-plan.md`

## Rules

- Follow whatever architecture rules were loaded in Step 1 — e.g. if the project enforces a single database context/connection, never introduce a second one, regardless of how convenient it would be for this feature.
- Pin explicit names for tables, keys, indexes, and constraints that match the project's existing naming convention (don't let the framework's auto-generated names diverge from the rest of the schema).
- Flag any check-constraint or validation that mirrors ones already enforced elsewhere in the schema — inconsistent duplicate constraints are a common source of subtle bugs.
- Don't design the DB layer around assumptions about the UI beyond what's actually needed — that coupling belongs in the application layer, not the schema.
<!-- dev-assistant:skill:db-design:end -->

<!-- dev-assistant:skill:grill-me:start -->
## grill-me

Deep requirements discovery through adversarial, one-question-at-a-time interviews that turn a rough feature idea into a decision-complete, implementation-ready spec before any design or code work begins. Grounds every question and every challenge in this project's real architecture rules, tech stack, and golden reference modules (auto-detected from a connected dev-assistant config.json, or from CLAUDE.md/AGENTS.md/architecture docs in the project). Produces .ai-work/REQUIREMENTS.md, PLAN.md, and PLAN-REVIEW-LOG.md with full REQ-###/AC-###/RISK-### traceability. Use this skill whenever the user pitches a new feature idea, says "grill me", "interview me about this", "help me think through the requirements", "let's nail down the spec before we build this", or wants a plan/spec for something feature-sized before writing any code — even if they don't name the skill directly and even if the idea sounds simple at first (simple-sounding features often hide the most unresolved decisions). Do not use for trivial, already-fully-specified changes like a one-line bug fix, a copy/typo fix, or a config value change — this skill is for feature-sized work where real requirements are still fuzzy.

# Grill Me (Deep Requirements Discovery)

A two-act skill for turning a rough idea into a hardened, implementation-ready plan.

**No code is written during this skill.** The whole point is to find the expensive mistakes on paper, where fixing them costs a sentence, not a rewrite. Explicit user sign-off is required before implementation starts.

This skill was generalized from a project-specific version so it can run in any codebase dev-assistant has connected to. Its questions are only as sharp as the project context behind them — a generic interview that never touches this project's real constraints is not worth running. Do the context-loading step properly before starting Act 1.

## Step 0: Load Project Context

Before asking a single question, find out what's actually true about this project — its stack, its architecture rules, and an example of a module done right. You'll use these to challenge the user's claims in Act 1 and to ground the plan in Act 2. Try these sources in order and stop at the first one that gives real signal:

1. **A connected dev-assistant config.** dev-assistant installs live as a sibling folder next to the project they're connected to (e.g. a project at `D:\Work\LIMS` might have dev-assistant at `D:\Work\dev-assistant`). Look up to two directories above this project's root for a `config.json` that either sits inside a folder literally named `dev-assistant`, or whose own `projectRoot` field (path-normalized) matches this project's root. If you find one, read `techStack`, `backendPattern`, `frontendPattern`, `apiPattern`, `architectureRules`, `goldenModuleSimple`, `goldenModuleWizard`, and `existingFeatures` — treat this as authoritative, it was built specifically for this project.
2. **Project docs**, if no config.json turns up. Read whichever of these exist: `CLAUDE.md`, `AGENTS.md`, `ARCHITECTURE_RULES.md`, `.agents/project-context/ARCHITECTURE_RULES.md`, `.agents/project-context/GOLDEN_MODULES.md`, `docs/architecture.md`. Extract the same categories of information from prose — stack, hard rules, and a reference module worth cloning.
3. **Auto-Detect Golden Module (NEW):** If no golden module is found, use `grep_search` and query the `graphify` knowledge graph (`graph.json`) to automatically find a reference file or module similar to the feature pitched by the user. Do this silently before starting Act 1.
4. **Ask directly**, if neither source gives you anything real. Don't invent architecture rules or guess a tech stack to fill the gap — a challenge based on a made-up rule is worse than no challenge at all. Ask the user for their stack and 2-3 hard constraints before Act 1 starts.

Keep whatever you load in mind for the rest of the interview — it's what makes the "adversarial" part of this skill work instead of just being a generic questionnaire.

## Act 1: Requirements Interview

**GRAPHIFY IMPACT ANALYSIS (Mandatory Check):** Before you ask the first question, query the `graphify` knowledge graph (or request the user to do so) for the specific files/modules the user's feature will touch. Analyze the dependency/caller graph to identify what might break. Use this graph context to ask surgical, targeted questions (e.g., "According to the graph, `OrderService.ts` is called by the billing cron job. How will your changes affect the cron job?").

Interview the user one question at a time. Never batch multiple questions into one turn — a list of five questions lets the user skim and half-answer all of them; one sharp question forces an actual decision before you move on.

For each answer, actively check it against the context you loaded in Step 0: does this contradict an architecture rule? Does it imply a pattern the golden module doesn't use? Does it silently assume something about an existing feature that isn't true? Push back when it does, and explain why using the actual rule or file, not a generic "are you sure?".

Cover these areas before you consider the interview done — not in a fixed order, and not as a checklist to read aloud, but as areas that need a real, specific answer by the end:

- **Goal and actor** — who is this for, and what are they trying to accomplish?
- **Workflow** — what triggers it, what are the steps, what does success look like?
- **Business rules and invariants** — what must always be true, what's forbidden?
- **Data** — inputs, outputs, states, and what happens across their lifecycle?
- **Safety** — who's authorized, what needs validation, what are the error cases?
- **Compatibility** — how does this fit the existing patterns and modules? Any migration impact?
- **Operations** — anything about deployment, rollback, or monitoring that matters here?
- **Verification** — how will anyone know this actually works when it's done?

As the user answers, write down each resolved point and mark it `[LOCKED]`. A locked decision is settled — don't relitigate it later in the same session unless the user explicitly reopens it. This matters because without a firm record, adversarial review in Act 2 has nothing solid to check the plan against, and the interview can drift in circles.

**Exit condition:** every area above has a specific, locked answer and nothing material is still ambiguous. Do not stop just because you've asked some fixed number of questions — a feature with a lot of hidden edge cases deserves a longer interview than one that turns out to be simple.

## Act 2: Adversarial Plan Review

Once Act 1 is locked, draft `REQUIREMENTS.md`, `PLAN.md`, and `TEST_CASES.md` into `.ai-work/` (create the directory if it doesn't exist). Give every requirement, acceptance criterion, and risk a stable ID so the plan and the review log can reference them precisely:

- `REQ-001`, `REQ-002`, ... — one per distinct requirement
- `AC-001`, `AC-002`, ... — one per acceptance criterion (Given/When/Then works well here)
- `RISK-001`, `RISK-002`, ... — one per identified risk
- `TEST-001`, `TEST-002`, ... — one per required unit/security/edge-case test in `TEST_CASES.md`

Then review the plan adversarially — actually try to find what's wrong with it rather than rubber-stamping your own draft. Look for gaps (a requirement with no corresponding plan step), contradictions (two requirements that can't both hold), missing error cases, and anywhere the plan quietly assumes something Step 0's context doesn't support. Ensure `TEST_CASES.md` covers edge cases and security validations.

Log every review round to `PLAN-REVIEW-LOG.md`, including what you found and what changed as a result. Loop — revise the plan, review again — until no material issues remain, up to a maximum of 5 rounds. If round 5 arrives and there's still a real disagreement about whether an issue is material, you are the final arbiter: decide, record the reasoning in the log, and move on. Five rounds of circling on the same point helps no one.

## Required Outputs

- `.ai-work/REQUIREMENTS.md` — locked requirements with `REQ-###` IDs
- `.ai-work/PLAN.md` — implementation plan with `REQ-###` / `AC-###` / `RISK-###` traceability
- `.ai-work/TEST_CASES.md` — test-driven specs, edge cases, and security tests with `TEST-###` IDs
- `.ai-work/PLAN-REVIEW-LOG.md` — every adversarial review round, findings, and resulting changes

## Exit to Implementation

Do not start implementing after Act 2 — stop and get explicit sign-off from the user on the plan first. Once they've signed off:

1. If this project has a `/prepare-feature` skill installed, suggest running it to load context and create a current-task file.
2. Then, if present, `/implement-from-plan`.
3. Then, if present, `/review-consistency`.

If none of those skills exist in this project, that's fine — just point the user at `PLAN.md` as the source of truth for whoever implements it next.
<!-- dev-assistant:skill:grill-me:end -->

<!-- dev-assistant:skill:live-context-verifier:start -->
## live-context-verifier

Enforce context freshness before touching any code. Verifies graphify node hierarchy and dependent modules to prevent working on stale or partial context.

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
<!-- dev-assistant:skill:live-context-verifier:end -->

<!-- dev-assistant:skill:pattern-clone:start -->
## pattern-clone

Clone the structure of an existing, working module instead of inventing a new pattern or reaching for generic framework conventions from memory. Use immediately after context-loader has identified the closest reference module — for any new CRUD endpoint, list page, wizard/multi-step form, or service that has a real sibling in this codebase to model after. Skip this only when nothing in the codebase is genuinely close, in which case say so rather than forcing a bad fit.

# Pattern Clone

A codebase with one consistent way of doing CRUD is easier to maintain than one with five slightly different ways that each seemed reasonable in isolation. This skill exists to keep it at one way.

## Rules

1. Find the one existing module with the closest real behavior to what you're building — not a pattern from a tutorial or from training data, an actual file in this repo.
2. Clone its structure: same folders, same file naming, same layering.
3. Rename only what's feature-specific — the entity name, the route, the service name. Everything structural stays the same.
4. Keep the same response shape and status codes.
5. Keep the same validation style.
6. Keep the same dependency-injection / wiring style.
7. Keep the same error-handling convention.
8. Reuse shared utilities instead of re-implementing them — if the reference module calls a shared pagination/mapping/timezone helper, call the same helper.
9. Don't introduce a new abstraction unless the same logic already repeats 3+ times across the codebase, and even then, flag it rather than deciding unilaterally.

## Do Not

- Invent a new base class or helper when an existing one already does the job
- Create a duplicate DTO/request/response type that's structurally identical to one that exists
- Silently change the reference module's established pattern "because it's better" — raise it as a separate conversation, don't fold it into an unrelated feature
- Mix conventions from two different existing modules into one new one

## Finding the Clone Target

Don't guess — check, in order:
1. `goldenModuleSimple` / `goldenModuleWizard` from a connected dev-assistant `config.json` (see `context-loader`), if the new feature matches that shape.
2. The `existingFeatures` list for the closest match by category (another simple CRUD master, another wizard, another read-only report).
3. If neither points anywhere good, ask which existing feature is the best reference rather than picking one arbitrarily — a wrong clone target propagates its mistakes into the new feature.

## Clone Verification Checklist

After cloning, confirm against the reference module:

- [ ] Folder structure matches
- [ ] Naming conventions match (entity, service, endpoint/component names)
- [ ] Response/output format matches
- [ ] Validation style matches
- [ ] Data-access pattern matches (whatever the reference module actually does — don't substitute a different style you happen to prefer)
- [ ] Error-handling matches
- [ ] Registration/wiring matches (DI container, routing, module registration — whatever this stack uses)

## Related Skills

- `context-loader` — run first to identify the correct reference module
- `code-review-quality` — verify the clone matches the reference module before calling the task done
<!-- dev-assistant:skill:pattern-clone:end -->

<!-- dev-assistant:skill:regression-guard:start -->
## regression-guard

Run this graphify-powered regression gate before completing any code change to ensure existing functionality and caller contracts remain 100% unbroken.

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
<!-- dev-assistant:skill:regression-guard:end -->

<!-- dev-assistant:skill:senior-engineer-mindset:start -->
## senior-engineer-mindset

Act like a 10+ year veteran Principal/Staff Software Engineer. Enforces minimal surgical changes, zero scope creep, maximum code reuse, and idiomatic best practices.

# Senior Engineer Mindset

When executing a coding task, channel the discipline of a 10+ year veteran Principal/Staff Software Engineer in the target programming language.

## 1. Minimal Surgical Changes (The Lazy Dev Ladder)

Before writing *any* code, you MUST mentally step through this strict 7-step ladder in order:
1. **Does this need to exist?** → No: skip it (YAGNI).
2. **Already in this codebase?** → Reuse it, don't rewrite.
3. **Stdlib does it?** → Use it.
4. **Native platform feature?** → Use it (e.g. `<input type="date">` instead of a heavy component).
5. **Installed dependency?** → Use it.
6. **One line?** → One line.
7. **Only then:** Write the minimum that works.

- Touch ONLY the exact lines necessary to solve the task or fix the bug.
- ZERO scope creep: Do not rewrite unrelated functions, reformat adjacent code, or "clean up" things outside the explicit scope of the user's request.
- Every line of code added introduces maintenance burden. Write as little code as possible to achieve the correct result.

## 2. Maximum Code Reuse

- Before writing any new logic, aggressively search the codebase (via `graphify` or search tools) for existing utilities, helper functions, or base classes that already solve the problem.
- Do not duplicate logic (e.g., date formatting, API error handling, retry logic). Reuse what exists.

## 3. Clean & Idiomatic Best Practices

- **Type Safety**: Use the language's type system correctly (e.g., generics, strict typing) without bypassing it (no `any` in TypeScript unless absolutely necessary).
- **Error Handling**: Do not swallow exceptions silently. Handle errors gracefully, log them properly, and bubble them up if they cannot be handled at the current layer.
- **Performance & Memory**: Avoid obvious performance pitfalls (e.g., N+1 database queries, unnecessary object allocations in tight loops, blocking the event loop).
- **Immutability & State**: Prefer immutable data structures and pure functions where applicable.

## 4. Professional Restraint

- If a user's request violates architectural rules or introduces a severe anti-pattern, push back professionally and explain WHY it is a bad idea, rather than blindly implementing it.
<!-- dev-assistant:skill:senior-engineer-mindset:end -->

<!-- dev-assistant:skill:test-agent:start -->
## test-agent

Build and run an acceptance-focused test matrix — backend, frontend, and integration checks — mapped to a feature's acceptance criteria, then produce a test report with a release recommendation. Use when writing tests, planning validation coverage, verifying acceptance criteria are actually met, or deciding whether a feature is ready to ship. Detects this project's real test tooling (dotnet test, npm test/jest/vitest, pytest, go test, or whatever else is actually configured) instead of assuming one stack.

# Test Agent

A feature isn't done because the code compiles — it's done because there's evidence it does what the acceptance criteria say it should. This skill produces that evidence.

## Step 1: Gather What "Done" Means

1. If `docs/specs/<feature>-acceptance.md` and `-spec.md` exist (produced by dev-assistant's `feature-docs` workflow, or by hand), read them — every acceptance criterion needs a corresponding test.
2. If they don't exist, ask for the acceptance criteria, or derive a reasonable set from the ticket/request and the actual code changed — don't skip straight to "looks fine to me."

## Step 2: Detect This Project's Real Test Tooling

Don't assume. Check what's actually configured:
- `package.json` `scripts` block for `test`/`test:unit`/`test:e2e` — could be jest, vitest, mocha, `ng test`, playwright, cypress, etc.
- A `.csproj`/test project + `dotnet test`
- `pytest.ini` / `pyproject.toml` `[tool.pytest]` + `pytest`
- `go.mod` + `go test ./...`
- A `Makefile` target like `make test`
- Any project-specific test runner mentioned in `CLAUDE.md`/`AGENTS.md`/a connected dev-assistant `config.json`

Use whichever of these actually exist in this repo — run the project's real commands, don't paste in a generic example.

## Step 3: Execute and Record

1. Run the detected backend/frontend/integration test commands.
2. For UI work, run whatever design/lint/accessibility checks this project already has configured (if any) — don't invent new ones it doesn't use.
3. For every acceptance criterion, record pass/fail with real evidence (actual command output), not an assumption.
4. Publish a release recommendation, including any known gaps.

## Required Output

- `docs/specs/<feature>-test-report.md`

## Test Report Structure

```text
## Test Report: <feature>

### Acceptance Criteria Coverage
| AC-### | Criterion | Test type | Result | Evidence |

### Backend Tests
<actual command run, and its real output>

### Frontend Tests
<actual command run, and its real output>

### Integration Checks
<API/endpoint smoke tests, DB migration validation, or whatever integration surface this feature touches>

### Release Recommendation
Ready / Not ready
Gaps:
```

## Rules

- Every critical acceptance criterion must be covered — don't silently skip one because it's inconvenient to test.
- Missing test evidence is a gate failure unless there's an explicit, stated reason it can't be tested right now.
- Never report a test as passing without having actually run it and captured the output — a plausible-sounding "should pass" is not evidence.
<!-- dev-assistant:skill:test-agent:end -->

<!-- dev-assistant:skill:code-reduction-audit:start -->
## code-reduction-audit

Audit the entire repository for over-engineering using graphify and search tools, outputting a master list of technical debt to delete.

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
<!-- dev-assistant:skill:code-reduction-audit:end -->

<!-- dev-assistant:skill:code-reduction-review:start -->
## code-reduction-review

Review the current diff or working files for over-engineering and provide a delete-list of code that can be replaced by one-liners or native features.

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
<!-- dev-assistant:skill:code-reduction-review:end -->

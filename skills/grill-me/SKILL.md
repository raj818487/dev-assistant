---
name: grill-me
description: Deep requirements discovery through adversarial, one-question-at-a-time interviews that turn a rough feature idea into a decision-complete, implementation-ready spec before any design or code work begins. Grounds every question and every challenge in this project's real architecture rules, tech stack, and golden reference modules (auto-detected from a connected dev-assistant config.json, or from CLAUDE.md/AGENTS.md/architecture docs in the project). Produces .ai-work/REQUIREMENTS.md, PLAN.md, and PLAN-REVIEW-LOG.md with full REQ-###/AC-###/RISK-### traceability. Use this skill whenever the user pitches a new feature idea, says "grill me", "interview me about this", "help me think through the requirements", "let's nail down the spec before we build this", or wants a plan/spec for something feature-sized before writing any code — even if they don't name the skill directly and even if the idea sounds simple at first (simple-sounding features often hide the most unresolved decisions). Do not use for trivial, already-fully-specified changes like a one-line bug fix, a copy/typo fix, or a config value change — this skill is for feature-sized work where real requirements are still fuzzy.
---

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

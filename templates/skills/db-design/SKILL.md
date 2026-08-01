---
name: db-design
description: Design database schema changes, queries, indexes, and migration/rollback plans for any new table, column, relationship, or data-access change — for whatever database and migration tool this project actually uses (PostgreSQL, MySQL, SQL Server, MongoDB, EF Core migrations, Prisma, Django, Rails, Alembic, Flyway, raw SQL, or anything else). Use whenever a feature needs new persisted data, a schema change, a new query shape, or an index/performance decision. Grounds every decision in this project's real architecture rules and existing schema conventions instead of generic textbook database advice.
---

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

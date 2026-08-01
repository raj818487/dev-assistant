---
applyTo: "**"
description: Clone the structure of an existing, working module instead of inventing a new pattern or reaching for generic framework conventions from memory. Use immediately after context-loader has identified the closest reference module — for any new CRUD endpoint, list page, wizard/multi-step form, or service that has a real sibling in this codebase to model after. Skip this only when nothing in the codebase is genuinely close, in which case say so rather than forcing a bad fit.
---

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

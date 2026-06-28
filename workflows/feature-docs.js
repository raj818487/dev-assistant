export const meta = {
  name: 'feature-docs',
  description: 'Generate feature docs: spec, acceptance criteria, UI map, gap analysis, and update project memory',
  phases: [
    { title: 'Discover',      detail: 'Scan codebase for feature implementation' },
    { title: 'Requirements',  detail: 'Generate spec, acceptance criteria, and UI map in parallel' },
    { title: 'Gap Analysis',  detail: 'Compare spec vs implementation and score gaps' },
    { title: 'Write & Memory',detail: 'Write docs and update AI agent memory' },
  ],
};

// Usage (in Claude Code chat):
//   Workflow({ name: 'feature-docs', args: { feature: 'User Management', date: '2026-06-28' } })
//   Workflow({ name: 'feature-docs', args: 'User Management' })
//
// connect.ps1 / connect.sh fills in __PROJECT_ROOT__, __MEMORY_DIR__,
// __PROJECT_NAME__, __TECH_STACK__ when copying this to the target project.

const rawArg  = args;
const feature = (rawArg && typeof rawArg === 'object' && rawArg.feature)
  ? rawArg.feature
  : (typeof rawArg === 'string' ? rawArg : 'unknown');
const dateStr = (rawArg && rawArg.date) ? rawArg.date : 'today';
const slug    = feature.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

const REPO       = '__PROJECT_ROOT__';
const MEMORY_DIR = '__MEMORY_DIR__';
const PROJECT    = '__PROJECT_NAME__';
const STACK      = '__TECH_STACK__';

// ─── Phase 1: Discover ────────────────────────────────────────────────────────
phase('Discover');

const DISCOVERY_SCHEMA = {
  type: 'object',
  required: ['implementedFiles', 'implementationSummary', 'isFullyImplemented', 'isPartiallyImplemented', 'missingParts'],
  properties: {
    implementedFiles:        { type: 'array', items: { type: 'string' } },
    implementationSummary:   { type: 'string' },
    isFullyImplemented:      { type: 'boolean' },
    isPartiallyImplemented:  { type: 'boolean' },
    existingSpecFiles:       { type: 'array', items: { type: 'string' } },
    apiEndpoints:            { type: 'array', items: { type: 'string' } },
    dbEntities:              { type: 'array', items: { type: 'string' } },
    permissions:             { type: 'array', items: { type: 'string' } },
    frontendRoutes:          { type: 'array', items: { type: 'string' } },
    missingParts:            { type: 'array', items: { type: 'string' } },
  }
};

const discovery = await agent(
  `You are a codebase analyst for the ${PROJECT} project at ${REPO}.
Stack: ${STACK}

Analyse the codebase for the "${feature}" feature across ALL layers:
- Backend (controllers, services, entities, migrations)
- Frontend (pages, components, models, services)
- Docs/specs (any existing spec files)

Return:
1. implementedFiles — every file that implements this feature (repo-relative paths)
2. implementationSummary — 2-3 sentence description of current state
3. isFullyImplemented / isPartiallyImplemented booleans
4. existingSpecFiles — any existing spec/doc files for this feature
5. apiEndpoints — REST endpoints (e.g. "GET /api/v1/users")
6. dbEntities — domain entity class names
7. permissions — permission constants used
8. frontendRoutes — client-side routes
9. missingParts — identified gaps (each as a short phrase)`,
  { schema: DISCOVERY_SCHEMA, label: `discover:${feature}`, phase: 'Discover' }
);

log(`${discovery.implementedFiles.length} files found · ${discovery.missingParts.length} gaps identified`);

// ─── Phase 2: Requirements (parallel) ────────────────────────────────────────
phase('Requirements');

const [spec, acceptance, uiMap] = await parallel([

  () => agent(
    `You are a requirements analyst for the ${PROJECT} project (stack: ${STACK}).
Generate a complete requirements spec for the "${feature}" feature.

Discovery findings:
${JSON.stringify(discovery, null, 2)}

Output complete Markdown for docs/specs/${slug}-spec.md with these sections:
# ${feature} — Requirements Spec
## 1. Goal & Business Purpose
## 2. Scope / Non-Goals
## 3. Actors & Roles
## 4. Functional Requirements (FR-001, FR-002, ...)
## 5. Business Rules (BR-001, ...)
## 6. Data Requirements
## 7. API Requirements
## 8. UX / UI Requirements
## 9. Security & Permissions
## 10. Reliability & Performance
## 11. Acceptance Criteria (Given/When/Then)
## 12. Dependencies
## 13. Open Decisions
## 14. Definition of Done`,
    { label: `spec:${slug}`, phase: 'Requirements' }
  ),

  () => agent(
    `You are a QA analyst for the ${PROJECT} project.
Generate acceptance criteria for the "${feature}" feature.

Discovery findings:
${JSON.stringify(discovery, null, 2)}

Produce at least 15 Given/When/Then scenarios covering:
- Happy path CRUD operations
- Mandatory field validation
- Permission / role checks
- Status toggle behaviour
- Edge cases (empty state, duplicates, large data)
- Negative cases (missing fields, unauthorised access)
- Integration points with other features

Output Markdown for docs/specs/${slug}-acceptance.md`,
    { label: `acceptance:${slug}`, phase: 'Requirements' }
  ),

  () => agent(
    `You are a UI analyst for the ${PROJECT} project (stack: ${STACK}).
Generate a UI component map for the "${feature}" feature.

Discovery findings:
${JSON.stringify(discovery, null, 2)}

Produce a Markdown table mapping each UI element to:
| UI Element | Component / File | CSS class / token | Shared wrapper | Permission | Data binding |

Then list any missing UI components that need to be built.

Output Markdown for docs/specs/${slug}-ui-map.md`,
    { label: `ui-map:${slug}`, phase: 'Requirements' }
  ),
]);

log('Spec, acceptance criteria, and UI map generated');

// ─── Phase 3: Gap Analysis ────────────────────────────────────────────────────
phase('Gap Analysis');

const GAP_SCHEMA = {
  type: 'object',
  required: ['summary', 'implemented', 'partial', 'missing', 'riskScore'],
  properties: {
    summary:          { type: 'string' },
    implemented:      { type: 'array', items: { type: 'string' } },
    partial:          {
      type: 'array',
      items: {
        type: 'object',
        required: ['item', 'done', 'missing'],
        properties: {
          item:    { type: 'string' },
          done:    { type: 'string' },
          missing: { type: 'string' },
        }
      }
    },
    missing: {
      type: 'array',
      items: {
        type: 'object',
        required: ['item', 'severity', 'complexity'],
        properties: {
          item:       { type: 'string' },
          severity:   { type: 'string', enum: ['Critical', 'High', 'Medium', 'Low'] },
          complexity: { type: 'string', enum: ['S', 'M', 'L', 'XL'] },
        }
      }
    },
    riskScore:          { type: 'string', enum: ['Critical', 'High', 'Medium', 'Low'] },
    prioritisedOrder:   { type: 'array', items: { type: 'string' } },
  }
};

const gapData = await agent(
  `Compare the spec against the implementation for "${feature}" in ${PROJECT}.

Requirements spec:
${spec}

Current implementation:
${JSON.stringify(discovery, null, 2)}

Classify each requirement item as: Implemented / Partial / Missing
Score each missing item: severity (Critical/High/Medium/Low) and complexity (S/M/L/XL).
Give an overall riskScore and a prioritised order for remaining work.`,
  { schema: GAP_SCHEMA, label: `gap:${slug}`, phase: 'Gap Analysis' }
);

const gapMd = `# ${feature} — Gap Analysis

> Generated: ${dateStr}

## Summary

${gapData.summary}

**Overall Risk:** ${gapData.riskScore}

---

## Implemented

${gapData.implemented.map(i => `- ${i}`).join('\n')}

---

## Partially Implemented

| Item | Done | Missing |
|------|------|---------|
${gapData.partial.map(p => `| ${p.item} | ${p.done} | ${p.missing} |`).join('\n')}

---

## Not Implemented

| Item | Severity | Complexity |
|------|----------|------------|
${gapData.missing.map(m => `| ${m.item} | ${m.severity} | ${m.complexity} |`).join('\n')}

---

## Priority Order for Remaining Work

${gapData.prioritisedOrder.map((p, i) => `${i + 1}. ${p}`).join('\n')}
`;

log(`Gap analysis: ${gapData.missing.length} missing items, risk: ${gapData.riskScore}`);

// ─── Phase 4: Write docs + update memory ─────────────────────────────────────
phase('Write & Memory');

const sep = process.platform === 'win32' ? '\\' : '/';
const repoSep = (p) => `${REPO}${sep}${p.replace(/\//g, sep)}`;

const specPath   = `docs/specs/${slug}-spec.md`;
const acceptPath = `docs/specs/${slug}-acceptance.md`;
const uiPath     = `docs/specs/${slug}-ui-map.md`;
const gapPath    = `docs/specs/${slug}-gap-analysis.md`;
const memFile    = `${MEMORY_DIR}${sep}project-feature-${slug}.md`;
const memIndex   = `${MEMORY_DIR}${sep}MEMORY.md`;

const icon = discovery.isFullyImplemented ? '✅' : discovery.isPartiallyImplemented ? '⚠️' : '❌';

const memContent = `---
name: feature-${slug}
description: ${feature} — implementation status, key files, gaps (updated ${dateStr})
metadata:
  type: project
---

${discovery.implementationSummary}

**Status:** ${icon} ${discovery.isFullyImplemented ? 'Fully implemented' : discovery.isPartiallyImplemented ? 'Partially implemented' : 'Not yet implemented'}

**Why:** Generated by feature-docs workflow. Check before coding or reviewing ${feature}.

**How to apply:** Read key files first, then check gap analysis for remaining work.

## Key Files
${discovery.implementedFiles.slice(0, 12).map(f => `- \`${f}\``).join('\n')}

## API Endpoints
${(discovery.apiEndpoints || []).map(e => `- \`${e}\``).join('\n') || '- None yet'}

## Permissions
${(discovery.permissions || []).map(p => `- \`${p}\``).join('\n') || '- None yet'}

## Known Gaps (${gapData.missing.length})
${gapData.missing.slice(0, 10).map(g => `- **[${g.severity}/${g.complexity}]** ${g.item}`).join('\n') || '- None'}

## Docs
- Spec: \`${specPath}\`
- Acceptance: \`${acceptPath}\`
- UI Map: \`${uiPath}\`
- Gap Analysis: \`${gapPath}\`
`;

await parallel([
  () => agent(`Write EXACTLY to ${repoSep(specPath)}. Write tool only. Full content verbatim:\n\n---BEGIN---\n${spec}\n---END---`,           { label: 'write:spec',       phase: 'Write & Memory' }),
  () => agent(`Write EXACTLY to ${repoSep(acceptPath)}. Write tool only. Full content verbatim:\n\n---BEGIN---\n${acceptance}\n---END---`, { label: 'write:acceptance',  phase: 'Write & Memory' }),
  () => agent(`Write EXACTLY to ${repoSep(uiPath)}. Write tool only. Full content verbatim:\n\n---BEGIN---\n${uiMap}\n---END---`,           { label: 'write:ui-map',     phase: 'Write & Memory' }),
  () => agent(`Write EXACTLY to ${repoSep(gapPath)}. Write tool only. Full content verbatim:\n\n---BEGIN---\n${gapMd}\n---END---`,         { label: 'write:gap',        phase: 'Write & Memory' }),
  () => agent(
    `Do two file operations, nothing else:
1. Write this to ${memFile}:\n---BEGIN---\n${memContent}\n---END---
2. Read ${memIndex}, check if "project-feature-${slug}.md" exists. If NOT, append this line to the end of the bullet list:
- [${feature} Feature](project-feature-${slug}.md) — ${icon} ${discovery.implementationSummary.slice(0, 80)}
Use Read, Write, and Edit tools only.`,
    { label: 'update:memory', phase: 'Write & Memory' }
  ),
]);

log('All docs written. Memory updated.');

return {
  feature,
  slug,
  project: PROJECT,
  docs: { specPath, acceptPath, uiPath, gapPath },
  implementedCount: discovery.implementedFiles.length,
  gapCount: gapData.missing.length,
  riskScore: gapData.riskScore,
};

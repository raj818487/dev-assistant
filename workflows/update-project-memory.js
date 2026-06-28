export const meta = {
  name: 'update-project-memory',
  description: 'Scan all implemented features and regenerate AI agent memory files for the connected project',
  phases: [
    { title: 'Scan',     detail: 'Discover all feature areas in the codebase' },
    { title: 'Summarise',detail: 'Generate per-feature status summaries in parallel' },
    { title: 'Memory',   detail: 'Write consolidated AI context to memory files' },
  ],
};

// Usage (in Claude Code chat):
//   Workflow({ name: 'update-project-memory', args: { date: '2026-06-28' } })
//
// connect.ps1 / connect.sh fills in __PROJECT_ROOT__, __MEMORY_DIR__,
// __PROJECT_NAME__, __TECH_STACK__ when copying this file to the target project.

const dateStr    = (args && args.date) ? args.date : 'today';
const REPO       = '__PROJECT_ROOT__';
const MEMORY_DIR = '__MEMORY_DIR__';
const PROJECT    = '__PROJECT_NAME__';
const STACK      = '__TECH_STACK__';

// ─── Phase 1: Scan ────────────────────────────────────────────────────────────
phase('Scan');

const FEATURES_SCHEMA = {
  type: 'object',
  required: ['features'],
  properties: {
    features: {
      type: 'array',
      items: {
        type: 'object',
        required: ['name', 'slug', 'area', 'primaryFiles'],
        properties: {
          name:            { type: 'string' },
          slug:            { type: 'string' },
          area:            { type: 'string' },
          primaryFiles:    { type: 'array', items: { type: 'string' } },
          hasBackend:      { type: 'boolean' },
          hasFrontend:     { type: 'boolean' },
          hasSpec:         { type: 'boolean' },
        }
      }
    }
  }
};

const featureMap = await agent(
  `Scan the ${PROJECT} project at ${REPO} and list every distinct feature/module.

Look at:
- Backend controllers, services, and API files under ${REPO}
- Frontend pages, components, and views under ${REPO}
- Spec/docs files under ${REPO}/docs/ (if they exist)

For each feature return:
- name: human-readable (e.g. "User Management", "Invoice CRUD")
- slug: kebab-case slug (e.g. "user-management", "invoice-crud")
- area: broad area (auth / master / billing / reporting / dashboard / other)
- primaryFiles: top 3 most important files (relative paths from ${REPO})
- hasBackend: whether a backend controller/service exists
- hasFrontend: whether a frontend page/component exists
- hasSpec: whether spec/doc files exist

Return ALL features you can find.`,
  { schema: FEATURES_SCHEMA, label: 'scan:features', phase: 'Scan' }
);

log(`Found ${featureMap.features.length} features`);

// ─── Phase 2: Summarise ───────────────────────────────────────────────────────
phase('Summarise');

const SUMMARY_SCHEMA = {
  type: 'object',
  required: ['name', 'slug', 'status', 'oneLiner', 'keyFiles', 'permissions', 'apiRoutes'],
  properties: {
    name:        { type: 'string' },
    slug:        { type: 'string' },
    status:      { type: 'string', enum: ['complete', 'partial', 'stub', 'missing'] },
    oneLiner:    { type: 'string' },
    keyFiles:    { type: 'array', items: { type: 'string' } },
    permissions: { type: 'array', items: { type: 'string' } },
    apiRoutes:   { type: 'array', items: { type: 'string' } },
    openGaps:    { type: 'array', items: { type: 'string' } },
  }
};

const summaries = await pipeline(
  featureMap.features,
  (f) => agent(
    `Summarise the "${f.name}" feature in the ${PROJECT} project at ${REPO}.

Primary files: ${JSON.stringify(f.primaryFiles)}
Area: ${f.area}
Stack: ${STACK}

Read the files. Check for permissions/roles if applicable. Check API routes.

Return:
- status: complete | partial | stub | missing
- oneLiner: one sentence describing what this feature does and its current state
- keyFiles: up to 6 most important files (paths relative to ${REPO})
- permissions: any permission/role constants used (empty array if none)
- apiRoutes: REST endpoints (e.g. "GET /api/v1/users") — empty array if none
- openGaps: clearly missing pieces (empty array if complete)`,
    { schema: SUMMARY_SCHEMA, label: `summary:${f.slug}`, phase: 'Summarise' }
  )
);

const valid = summaries.filter(Boolean);
log(`${valid.length}/${featureMap.features.length} summaries collected`);

// ─── Phase 3: Write memory files ──────────────────────────────────────────────
phase('Memory');

const complete = valid.filter(s => s.status === 'complete');
const partial  = valid.filter(s => s.status === 'partial');
const stub     = valid.filter(s => s.status === 'stub' || s.status === 'missing');

const projectContextContent = `---
name: project-context-snapshot
description: Full ${PROJECT} feature inventory and status snapshot (last updated ${dateStr})
metadata:
  type: project
---

# ${PROJECT} — Feature Inventory

Last updated: ${dateStr}

## Stack
${STACK}

## Feature Status

### Complete (${complete.length})
${complete.map(s => `- **${s.name}**: ${s.oneLiner}`).join('\n')}

### Partial (${partial.length})
${partial.map(s => `- **${s.name}**: ${s.oneLiner}${s.openGaps.length ? ` — gaps: ${s.openGaps.slice(0,2).join(', ')}` : ''}`).join('\n')}

### Stub / Missing (${stub.length})
${stub.map(s => `- **${s.name}**: ${s.oneLiner}`).join('\n')}

---

## All Permissions
${[...new Set(valid.flatMap(s => s.permissions))].sort().map(p => `- \`${p}\``).join('\n') || '- none recorded'}

## All API Routes
${[...new Set(valid.flatMap(s => s.apiRoutes))].sort().map(r => `- \`${r}\``).join('\n') || '- none recorded'}
`;

await parallel([
  () => agent(
    `Write this content EXACTLY to ${MEMORY_DIR}\\project-context-snapshot.md (Windows) or ${MEMORY_DIR}/project-context-snapshot.md (Mac/Linux). Use Write tool only.\n\n---BEGIN---\n${projectContextContent}\n---END---`,
    { label: 'write:project-context', phase: 'Memory' }
  ),
  ...valid.map(s => () => {
    const icon = s.status === 'complete' ? '✅' : s.status === 'partial' ? '⚠️' : '🔲';
    const content = `---
name: feature-${s.slug}
description: ${s.name} — ${s.status} (updated ${dateStr})
metadata:
  type: project
---

${s.oneLiner}

**Status:** ${icon} ${s.status}

**Why:** Auto-generated by update-project-memory workflow.

**How to apply:** Use keyFiles as entry points when coding or reviewing ${s.name}.

## Key Files
${s.keyFiles.map(f => `- \`${f}\``).join('\n')}

## Permissions
${s.permissions.map(p => `- \`${p}\``).join('\n') || '- None'}

## API Routes
${s.apiRoutes.map(r => `- \`${r}\``).join('\n') || '- None'}

## Open Gaps
${s.openGaps.map(g => `- ${g}`).join('\n') || '- None'}
`;
    return agent(
      `Write this content EXACTLY to ${MEMORY_DIR}\\project-feature-${s.slug}.md (Windows) or ${MEMORY_DIR}/project-feature-${s.slug}.md (Mac/Linux). Write tool only.\n\n---BEGIN---\n${content}\n---END---`,
      { label: `write:mem:${s.slug}`, phase: 'Memory' }
    );
  }),
]);

const memIndex = `# Project Memory Index

Auto-generated by update-project-memory workflow (${dateStr}).

## Project
- [Project Context](project-context-snapshot.md) — Full feature inventory, permissions, and API routes

## Features
${valid.map(s => {
  const icon = s.status === 'complete' ? '✅' : s.status === 'partial' ? '⚠️' : '🔲';
  return `- [${s.name}](project-feature-${s.slug}.md) — ${icon} ${s.oneLiner.slice(0, 80)}`;
}).join('\n')}
`;

await agent(
  `Write this content EXACTLY to ${MEMORY_DIR}\\MEMORY.md (Windows) or ${MEMORY_DIR}/MEMORY.md (Mac/Linux). Write tool only. REPLACES the existing file.\n\n---BEGIN---\n${memIndex}\n---END---`,
  { label: 'write:MEMORY.md', phase: 'Memory' }
);

log('Project memory updated.');

return {
  date: dateStr,
  project: PROJECT,
  totalFeatures: featureMap.features.length,
  complete: complete.length,
  partial: partial.length,
  stub: stub.length,
  memoryFilesWritten: valid.length + 2,
};

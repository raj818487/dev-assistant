# Graph Report - .  (2026-07-06)

## Corpus Check
- Corpus is ~6,965 words - fits in a single context window. You may not need a graph.

## Summary
- 73 nodes · 87 edges · 11 communities (9 shown, 2 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 50,052 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_MCP Query Server Core|MCP Query Server Core]]
- [[_COMMUNITY_Core Commands & Overview|Core Commands & Overview]]
- [[_COMMUNITY_Feature Docs Workflow|Feature Docs Workflow]]
- [[_COMMUNITY_HTTP Request Handler|HTTP Request Handler]]
- [[_COMMUNITY_Installation & Dependencies|Installation & Dependencies]]
- [[_COMMUNITY_Project Memory Update Internals|Project Memory Update Internals]]
- [[_COMMUNITY_Feature Docs Script Internals|Feature Docs Script Internals]]
- [[_COMMUNITY_Install Script Entry Point|Install Script Entry Point]]
- [[_COMMUNITY_Connect Script Entry Point|Connect Script Entry Point]]

## God Nodes (most connected - your core abstractions)
1. `handle_question()` - 9 edges
2. `Handler` - 7 edges
3. `server.py` - 7 edges
4. `dev-assistant` - 6 edges
5. `Claude CLI / Claude Code` - 5 edges
6. `docs/specs/ output directory` - 5 edges
7. `gq()` - 4 edges
8. `_run_claude()` - 4 edges
9. `install.ps1` - 4 edges
10. `connect.ps1` - 4 edges

## Surprising Connections (you probably didn't know these)
- `connect.ps1` --references--> `workflows/ directory`  [EXTRACTED]
  README.md → README.md  _Bridges community 1 → community 2_
- `server.py` --references--> `Claude CLI / Claude Code`  [EXTRACTED]
  README.md → README.md  _Bridges community 1 → community 4_
- `update-project-memory workflow` --references--> `Claude CLI / Claude Code`  [EXTRACTED]
  README.md → README.md  _Bridges community 4 → community 2_

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Project setup flow: install then connect then run** — dev_assistant_readme_install_ps1, dev_assistant_readme_connect_ps1, dev_assistant_readme_server_py, dev_assistant_readme_config_json [EXTRACTED 0.90]
- **feature-docs workflow generated documentation set** — dev_assistant_readme_feature_spec_md, dev_assistant_readme_feature_acceptance_md, dev_assistant_readme_feature_ui_map_md, dev_assistant_readme_feature_gap_analysis_md [EXTRACTED 0.90]
- **Supported assistant query intents** — dev_assistant_readme_implementation_planning_chatbot, dev_assistant_readme_change_impact_analysis, dev_assistant_readme_codebase_qa, dev_assistant_readme_intent_detection [EXTRACTED 0.90]

## Communities (11 total, 2 thin omitted)

### Community 0 - "MCP Query Server Core"
Cohesion: 0.23
Nodes (13): build_explain_prompt(), build_impact_prompt(), build_plan_prompt(), detect_intent(), extract_entity_name(), gather_context(), gq(), handle_question() (+5 more)

### Community 1 - "Core Commands & Overview"
Cohesion: 0.18
Nodes (12): Change impact analysis, Codebase Q&A, COMMANDS.md, config.json, connect.ps1, connect.sh, graph.json (graphify-out), graphify hook install (+4 more)

### Community 2 - "Feature Docs Workflow"
Cohesion: 0.25
Nodes (9): AI context workflows, docs/specs/ output directory, <feature>-acceptance.md, feature-docs workflow, <feature>-gap-analysis.md, <feature>-spec.md, <feature>-ui-map.md, update-project-memory workflow (+1 more)

### Community 3 - "HTTP Request Handler"
Cohesion: 0.32
Nodes (3): BaseHTTPRequestHandler, graph_node_count(), Handler

### Community 4 - "Installation & Dependencies"
Cohesion: 0.43
Nodes (8): Claude CLI / Claude Code, dev-assistant, graphify, graphifyy (PyPI package), install.ps1, install.sh, Python 3.10+, uv (Astral)

### Community 5 - "Project Memory Update Internals"
Cohesion: 0.25
Nodes (7): complete, FEATURES_SCHEMA, meta, partial, stub, SUMMARY_SCHEMA, valid

### Community 6 - "Feature Docs Script Internals"
Cohesion: 0.33
Nodes (4): DISCOVERY_SCHEMA, GAP_SCHEMA, meta, slug

## Knowledge Gaps
- **24 isolated node(s):** `connect.sh script`, `install.sh script`, `PATH`, `meta`, `slug` (+19 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Claude CLI / Claude Code` connect `Installation & Dependencies` to `Core Commands & Overview`, `Feature Docs Workflow`?**
  _High betweenness centrality (0.072) - this node is a cross-community bridge._
- **Why does `server.py` connect `Core Commands & Overview` to `Installation & Dependencies`?**
  _High betweenness centrality (0.061) - this node is a cross-community bridge._
- **What connects `connect.sh script`, `install.sh script`, `PATH` to the rest of the system?**
  _28 weakly-connected nodes found - possible documentation gaps or missing edges._
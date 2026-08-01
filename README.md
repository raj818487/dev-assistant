# omni-plugin

A plug-and-play AI assistant for any software project.

Connect it to your codebase once and get:

- **Implementation planning chatbot** — describe a new feature, get exact file paths, implementation order, and impact map
- **Change impact analysis** — ask what will break before you change anything
- **Codebase Q&A** — plain English answers about how your project works
- **AI context workflows** — auto-generate feature docs, gap analysis, and Claude memory files

Built on [graphify](https://pypi.org/project/graphifyy/) — maps your entire codebase into a queryable knowledge graph.

---

## Quick Start

### Step 1 — Install & Connect (All-in-One)

Run this single command **inside the root directory of the project you want to connect**:

```bash
npx omni-plugin
```

This will:
- Check and install **Python** & **uv**
- Install **graphify**
- Prompt you for your **Tech Stack** and **Port**
- Automatically build the knowledge graph (`graphify-out/graph.json`)
- Install coding rules into **Cursor, Copilot, Gemini CLI, and Codex** formats

#### How the Graph Build Works
The command first tries to build a rich semantic graph using **Claude Code CLI**.

If Claude fails or is not installed, graphify still runs its **local AST (Abstract Syntax Tree)** extraction, which parses all your code files completely offline with no API key required. The graph file will be created regardless.

---

### Step 2 — Start the Assistant Chatbot

```bash
npx omni-plugin serve
```

Open **http://localhost:8765** in your browser to start chatting.

---

## Manually Rebuilding the Graph

If graphify did not generate a complete graph during setup, or after large code changes, you can rebuild it manually.

Run these commands from your project root:

### Option A — Full rebuild with Claude (best quality, requires Claude Code CLI)
```bash
graphify extract . --backend claude-cli
```

### Option B — AST-only rebuild (100% offline, no API key needed)
```bash
graphify extract . --code-only
```

### Option C — Auto-detect via omni-plugin CLI shortcut
```bash
npx omni-plugin graphify
```
*(This tries Claude first, then falls back to AST-only automatically)*

---

## Other Commands

### Generate an Interactive HTML Tree Map
```bash
npx omni-plugin graphify-tree
```
Opens `graphify-out/GRAPH_TREE.html` — a collapsible D3 visual map of your entire codebase.

### Generate a Mermaid Call-Flow Diagram
```bash
npx omni-plugin graphify-callflow
```
Opens a Mermaid-based architecture call-flow HTML file.

---

## What you can ask the Chatbot

| Intent | Example questions |
|--------|------------------|
| **Plan a new feature** | "I want to add a Customer Registration page" |
| | "Add an Invoice module with line items and PDF export" |
| **Impact analysis** | "What will break if I change the UserService?" |
| | "Is it safe to rename the payments table?" |
| **Codebase Q&A** | "How does authentication work end-to-end?" |
| | "What calls the BranchService.Create method?" |

---

## Coding Skills Installed

`npx omni-plugin` copies these AI coding rules into your project for every supported editor:

| Skill | What it does |
|-------|---------------|
| `regression-guard` | Ensures changes never break existing caller contracts |
| `live-context-verifier` | Forces AI to check graphify graph before modifying files |
| `senior-engineer-mindset` | Enforces minimal surgical changes, zero scope creep |
| `grill-me` | Adversarial requirements discovery interview before coding |
| `context-loader` | Loads real project architecture rules + reference module |
| `pattern-clone` | Clones sibling module structure instead of inventing patterns |
| `db-design` | Schema, indexes, and migration planning |
| `code-review-quality` | Final review gate before calling a task done |
| `test-agent` | Runs an acceptance test matrix against project test tooling |

Installed to:
- **Cursor** → `.cursor/rules/<skill>.mdc`
- **GitHub Copilot** → `.github/instructions/<skill>.instructions.md`
- **Gemini CLI** → `GEMINI.md`
- **Codex / Antigravity** → `AGENTS.md`

---

## Requirements

- Python 3.10+
- [uv](https://astral.sh/uv/) — to install graphify (auto-installed by the script)
- graphify: installed automatically via `uv tool install graphifyy`
- `markdown`, `xhtml2pdf`, `python-docx` — for PDF/DOCX export (auto-installed)

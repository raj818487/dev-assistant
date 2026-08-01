#!/usr/bin/env bash
# omni-plugin — connect to a project (Mac/Linux)
# Ask: project path + tech stack. Everything else is auto-detected.

set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "  omni-plugin — connect"
echo "  ----------------------------------------"
echo ""

# 1. Two questions
PROJECT_ROOT="$PWD"
echo "  Project path: $PROJECT_ROOT"
PROJECT_ROOT="${PROJECT_ROOT//\"/}"
if [ ! -d "$PROJECT_ROOT" ]; then
  echo "  ERROR: path not found: $PROJECT_ROOT"; exit 1
fi

FOLDER_NAME=$(basename "$PROJECT_ROOT")
read -rp "  Tech stack (e.g. 'Angular + .NET + PostgreSQL'): " TECH_STACK
PROJECT_NAME="$FOLDER_NAME"

read -rp "  Chat server port [8765]: " PORT_INPUT
PORT="${PORT_INPUT:-8765}"

echo ""
echo "  Got it. Auto-detecting the rest from your codebase..."

# 2. Check graphify
if ! command -v graphify &>/dev/null; then
  echo "  graphify not found. Run ./install.sh first."; exit 1
fi

# 3. Choose AI backend & Build knowledge graph
echo ""
echo "  Which AI backend should graphify use for semantic enrichment?"
echo "  (Semantic = richer graph. AST-only = offline, no API key needed)"
echo ""
echo "    [1] Claude Code CLI   (needs Claude CLI installed)"
echo "    [2] Cursor            (needs Cursor IDE installed)"
echo "    [3] Gemini            (needs GEMINI_API_KEY)"
echo "    [4] Agy / Antigravity (needs agy CLI installed)"
echo "    [5] Codex / OpenAI    (needs OPENAI_API_KEY)"
echo "    [6] AST only          (offline, no AI needed — always works)"
echo ""
printf "  Enter choice [6]: "; read BACKEND_CHOICE
[ -z "$BACKEND_CHOICE" ] && BACKEND_CHOICE="6"

GRAPHIFY_BACKEND=""
BACKEND_OK=0

case "$BACKEND_CHOICE" in
  1)
    if command -v claude &>/dev/null; then
      echo "  [OK] Claude CLI found."
      GRAPHIFY_BACKEND="claude-cli"; BACKEND_OK=1
    else
      echo "  [WARN] Claude CLI not found. Download from https://claude.ai/download"
      echo "         Falling back to AST-only."
    fi ;;
  2)
    # Cursor IDE — detect install, try claude-cli layer Cursor ships with
    CURSOR_FOUND=0
    command -v cursor &>/dev/null && CURSOR_FOUND=1
    [ -f "/Applications/Cursor.app/Contents/MacOS/Cursor" ] && CURSOR_FOUND=1
    [ -f "$HOME/.local/share/cursor/cursor" ] && CURSOR_FOUND=1
    if [ "$CURSOR_FOUND" = "1" ]; then
      echo "  [OK] Cursor IDE detected."
      echo "  [INFO] Graphify will use the claude-cli layer Cursor ships with."
      if command -v claude &>/dev/null; then
        GRAPHIFY_BACKEND="claude-cli"; BACKEND_OK=1
        echo "  [OK] Claude CLI (via Cursor env) available."
      else
        echo "  [INFO] Claude CLI not found separately. Using AST-only + Cursor IDE for chat."
      fi
    else
      echo "  [WARN] Cursor not found. Download from https://cursor.com"
      echo "         Falling back to AST-only."
    fi ;;
  3)
    if [ -z "$GEMINI_API_KEY" ]; then
      printf "  Enter GEMINI_API_KEY: "; read GEMINI_API_KEY; export GEMINI_API_KEY
    fi
    if [ -n "$GEMINI_API_KEY" ]; then
      echo "  [OK] Gemini backend configured."
      GRAPHIFY_BACKEND="gemini"; BACKEND_OK=1
    else
      echo "  [WARN] No Gemini key. Falling back to AST-only."
    fi ;;
  4)
    if command -v agy &>/dev/null || command -v antigravity &>/dev/null; then
      echo "  [INFO] Antigravity found. graphify uses openai/gemini/claude for semantic enrichment."
      echo "         Using AST-only. Set OPENAI_API_KEY and choose [5] for semantic enrichment."
    else
      echo "  [WARN] Agy/Antigravity CLI not found. Download from https://antigravity.dev"
    fi ;;
  5)
    if [ -z "$OPENAI_API_KEY" ]; then
      printf "  Enter OPENAI_API_KEY: "; read OPENAI_API_KEY; export OPENAI_API_KEY
    fi
    if [ -n "$OPENAI_API_KEY" ]; then
      echo "  [OK] OpenAI/Codex backend configured."
      GRAPHIFY_BACKEND="openai"; BACKEND_OK=1
    else
      echo "  [WARN] No OpenAI key. Falling back to AST-only."
    fi ;;
  6|*)
    echo "  [OK] AST-only selected — no API key needed." ;;
esac

echo ""
echo "  [1/4] Building knowledge graph (may take 2-5 min)..."

run_ast_only() {
  echo "  Extracting AST (code structure, no LLM)..."
  graphify extract . --code-only --no-gitignore || graphify extract . --code-only
}

cd "$PROJECT_ROOT" || exit 1
if [ "$BACKEND_OK" = "1" ] && [ -n "$GRAPHIFY_BACKEND" ]; then
  echo "  Using backend: $GRAPHIFY_BACKEND"
  if ! graphify extract . --backend "$GRAPHIFY_BACKEND" --no-gitignore; then
    echo "  [WARN] Semantic extraction failed. Falling back to AST-only..."
    run_ast_only
  fi
else
  run_ast_only
fi
cd - > /dev/null
cd "$HERE"

GRAPH_PATH="$PROJECT_ROOT/graphify-out/graph.json"
if [ -f "$GRAPH_PATH" ]; then
  echo "  [OK] Graph built."
else
  echo "  [WARN] graph.json not found. Chat server will start but graph queries won't work."
  echo "         Re-run: graphify extract . --code-only --no-gitignore"
fi


# 4. Auto-detect config using Claude
echo "  [2/4] Auto-detecting project config with Claude..."

AUTO_PROMPT="You are analysing a software project to configure an AI assistant.

Project path: $PROJECT_ROOT
Tech stack: $TECH_STACK

Scan the project directory. Look at:
- CLAUDE.md, AGENTS.md, README.md for architecture rules
- Backend controllers/routes to find existing features and API patterns
- Frontend pages/components to find existing features
- The simplest complete CRUD file as the golden simple module
- The most complex multi-step form/wizard as the golden wizard module

Return ONLY a valid JSON object, no markdown, no explanation:
{
  \"architectureRules\": [\"rule 1\", \"rule 2\"],
  \"existingFeatures\": [\"Feature A\", \"Feature B\"],
  \"goldenModuleSimple\": \"relative/path/to/simplest/crud/file\",
  \"goldenModuleWizard\": \"relative/path/to/wizard/file or empty string\",
  \"apiPattern\": \"/api/v1/<resource> or detected pattern\",
  \"backendPattern\": \"one sentence about backend structure\",
  \"frontendPattern\": \"one sentence about frontend structure\"
}"

SAFE_SLUG=$(echo "$PROJECT_ROOT" | tr ':/\\ ' '----' | tr -s '-')
MEM_DIR="$HOME/.claude/projects/$SAFE_SLUG/memory"
mkdir -p "$MEM_DIR"

RAW_CONFIG=""
if command -v claude &>/dev/null; then
  TMP=$(mktemp)
  echo "$AUTO_PROMPT" > "$TMP"
  RAW_CONFIG=$(claude --print < "$TMP" 2>/dev/null || echo "")
  rm -f "$TMP"
fi

# Extract JSON from response
ARCH_RULES='[]'
FEATURES='[]'
GOLDEN_SIMPLE=''
GOLDEN_WIZARD=''
API_PATTERN='/api/v1/<resource>'
BACKEND_PATTERN=''
FRONTEND_PATTERN=''

if [ -n "$RAW_CONFIG" ]; then
  # Try to parse with python3
  PARSED=$(echo "$RAW_CONFIG" | python3 -c "
import sys, json, re
raw = sys.stdin.read()
m = re.search(r'\{[\s\S]*\}', raw)
if m:
    try:
        d = json.loads(m.group())
        print(json.dumps(d))
    except: pass
" 2>/dev/null || echo "")
  if [ -n "$PARSED" ]; then
    ARCH_RULES=$(echo "$PARSED"  | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('architectureRules',[])))")
    FEATURES=$(echo "$PARSED"    | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('existingFeatures',[])))")
    GOLDEN_SIMPLE=$(echo "$PARSED" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('goldenModuleSimple',''))")
    GOLDEN_WIZARD=$(echo "$PARSED" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('goldenModuleWizard',''))")
    API_PATTERN=$(echo "$PARSED" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('apiPattern','/api/v1/<resource>'))")
    BACKEND_PATTERN=$(echo "$PARSED" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('backendPattern',''))")
    FRONTEND_PATTERN=$(echo "$PARSED" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('frontendPattern',''))")
    echo "  Auto-detection complete."
  else
    echo "  Auto-detection returned unexpected output. Using defaults."
  fi
else
  echo "  Claude not available. Using defaults."
fi

# 5. Write config.json
echo "  [3/4] Writing config.json..."

# Inject mandatory anti-regression and senior engineer rules
ARCH_RULES=$(echo "$ARCH_RULES" | python3 -c '
import sys, json
try:
    rules = json.load(sys.stdin)
    if not isinstance(rules, list): rules = []
except:
    rules = []
rules.extend([
    "NEVER_BREAK_EXISTING_FUNCTIONALITY: Every code change must preserve existing working behavior, preserve public API contracts/signatures, and pass graphify regression checks before finishing.",
    "ALWAYS_VERIFY_LATEST_CONTEXT: AI agents must query the latest graphify codebase graph and inspect dependent modules before modifying files.",
    "SENIOR_ENGINEER_SURGICAL_EDITS: Write code like a 10+ year senior engineer in the language—make minimal surgical edits, maximize reuse of existing project utilities, and avoid unnecessary refactoring."
])
print(json.dumps(rules))
')

cat > "$PROJECT_ROOT/dev-assistant.json" <<EOF
{
  "projectName": "$PROJECT_NAME",
  "projectRoot": "$PROJECT_ROOT",
  "graphPath": "$GRAPH_PATH",
  "techStack": "$TECH_STACK",
  "backendPattern": "$BACKEND_PATTERN",
  "frontendPattern": "$FRONTEND_PATTERN",
  "apiPattern": "$API_PATTERN",
  "architectureRules": $ARCH_RULES,
  "goldenModuleSimple": "$GOLDEN_SIMPLE",
  "goldenModuleWizard": "$GOLDEN_WIZARD",
  "existingFeatures": $FEATURES,
  "memoryDir": "$MEM_DIR",
  "port": $PORT
}
EOF
echo "  dev-assistant.json written to project."

# 6. Copy templates + install workflows
echo "  [4/4] Installing files into project..."

[ ! -f "$PROJECT_ROOT/.graphifyignore" ] && cp "$HERE/templates/graphifyignore" "$PROJECT_ROOT/.graphifyignore" && echo "  .graphifyignore installed."

# Auto-Gitignore
GITIGNORE="$PROJECT_ROOT/.gitignore"
if [ -f "$GITIGNORE" ]; then
  if ! grep -q "graphify-out" "$GITIGNORE"; then
    printf "\n# --- AI & dev-assistant ignores ---\ngraphify-out/\n.claude/projects/\n" >> "$GITIGNORE"
    echo "  .gitignore updated with AI ignores."
  fi
else
  printf "\n# --- AI & dev-assistant ignores ---\ngraphify-out/\n.claude/projects/\n" > "$GITIGNORE"
  echo "  .gitignore created with AI ignores."
fi

# Git Hook Installer
GITHOOKS="$PROJECT_ROOT/.git/hooks"
if [ -d "$GITHOOKS" ]; then
  for HOOK in post-merge post-checkout; do
    if [ ! -f "$GITHOOKS/$HOOK" ]; then
      printf "#!/bin/sh\ngraphify . --backend claude-cli > /dev/null 2>&1 &\n" > "$GITHOOKS/$HOOK"
      chmod +x "$GITHOOKS/$HOOK"
      echo "  Git hook installed: $HOOK"
    fi
  done
fi
cp "$HERE/docs_export.py" "$PROJECT_ROOT/docs_export.py"
echo "  docs_export.py installed."

WF_DIR="$PROJECT_ROOT/.claude/workflows"
mkdir -p "$WF_DIR"

for WF in update-project-memory.js feature-docs.js; do
  SRC="$HERE/workflows/$WF"
  DST="$WF_DIR/$WF"
  if [ -f "$SRC" ]; then
    sed -e "s|__PROJECT_ROOT__|$PROJECT_ROOT|g" \
        -e "s|__MEMORY_DIR__|$MEM_DIR|g" \
        -e "s|__PROJECT_NAME__|$PROJECT_NAME|g" \
        -e "s|__TECH_STACK__|$TECH_STACK|g" \
        "$SRC" > "$DST"
    echo "  Workflow installed: $WF"
  fi
done

# Skills (e.g. grill-me, context-loader, pattern-clone, db-design, code-review-quality, test-agent)
SKILLS_SRC_DIR="$HERE/skills"
if [ -d "$SKILLS_SRC_DIR" ]; then
  for skillDir in "$SKILLS_SRC_DIR"/*/; do
    [ -d "$skillDir" ] || continue
    skillName=$(basename "$skillDir")
    dst="$PROJECT_ROOT/.claude/skills/$skillName"
    mkdir -p "$dst"
    cp -r "$skillDir"* "$dst/"
    echo "  Skill installed: $skillName"
  done

  # Fan out the same skills to Cursor / Copilot / Gemini / Codex
  python3 "$HERE/generate_agent_adapters.py" --project-root "$PROJECT_ROOT" | sed 's/^/  /'
  echo "  Agent adapters generated (Cursor, Copilot, Gemini, Codex)."
fi

# 7. COMMANDS.md
TODAY=$(date +%Y-%m-%d)
cat > "$HERE/COMMANDS.md" <<EOF
# dev-assistant commands for $PROJECT_NAME

## Start the chatbot
\`\`\`bash
cd "$HERE"
python server.py
\`\`\`
Open: http://localhost:$PORT

## Rebuild the graph
\`\`\`bash
cd "$PROJECT_ROOT"
graphify . --backend claude-cli
\`\`\`

## Update AI memory (in Claude Code chat)
\`\`\`
Workflow({ name: 'update-project-memory', args: { date: '$TODAY' } })
\`\`\`

## Generate feature docs (in Claude Code chat)
\`\`\`
Workflow({ name: 'feature-docs', args: { feature: 'Your Feature Name', date: '$TODAY' } })
\`\`\`

## Export generated docs as PDF / DOCX
\`\`\`bash
cd "$PROJECT_ROOT"
python docs_export.py "docs/specs/<feature-slug>-*.md" --formats pdf,docx
\`\`\`

## Installed Claude Code skills
grill-me, context-loader, pattern-clone, db-design, code-review-quality, test-agent
(auto-discovered from .claude/skills/ -- no slash command needed, Claude decides when to use them)

## Re-generate Cursor / Copilot / Gemini / Codex adapters
(run after editing any skill under .claude/skills/)
\`\`\`bash
cd "$HERE"
python3 generate_agent_adapters.py --project-root "$PROJECT_ROOT"
\`\`\`
EOF
echo "  COMMANDS.md written."

echo ""
echo "  All done!"
echo ""
echo "  Start the assistant:"
echo "    npx omni-plugin serve"
echo ""
echo "  Open in browser: http://localhost:$PORT"
echo ""
echo "  Edit $PROJECT_ROOT/dev-assistant.json to adjust if anything looks wrong."
echo ""

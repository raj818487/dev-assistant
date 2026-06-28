#!/usr/bin/env bash
# dev-assistant — connect to a project (Mac/Linux)
# Ask: project path + tech stack. Everything else is auto-detected.

set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "  dev-assistant — connect"
echo "  ----------------------------------------"
echo ""

# 1. Two questions
read -rp "  Project path (absolute): " PROJECT_ROOT
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

# 3. Build knowledge graph
echo "  [1/4] Building knowledge graph (may take 2-5 min)..."
cd "$PROJECT_ROOT"
if graphify . --backend claude-cli; then
  echo "  Graph built."
else
  echo "  Graph build failed. Continuing with partial config."
fi
cd "$HERE"

GRAPH_PATH="$PROJECT_ROOT/graphify-out/graph.json"

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

cat > "$HERE/config.json" <<EOF
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
echo "  config.json written."

# 6. Copy templates + install workflows
echo "  [4/4] Installing files into project..."

[ ! -f "$PROJECT_ROOT/.graphifyignore" ] && cp "$HERE/templates/graphifyignore" "$PROJECT_ROOT/.graphifyignore" && echo "  .graphifyignore installed."

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
EOF
echo "  COMMANDS.md written."

echo ""
echo "  All done!"
echo ""
echo "  Start: python \"$HERE/server.py\""
echo "  Open:  http://localhost:$PORT"
echo ""

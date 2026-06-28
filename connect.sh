#!/usr/bin/env bash
# dev-assistant — connect to a project (Mac/Linux)
# Usage: ./connect.sh

set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "  dev-assistant — connect to a project"
echo "  ----------------------------------------"
echo ""

# 1. Project root
read -rp "  Project root path (absolute): " PROJECT_ROOT
PROJECT_ROOT="${PROJECT_ROOT//\"/}"
if [ ! -d "$PROJECT_ROOT" ]; then
  echo "  ERROR: Path not found: $PROJECT_ROOT"
  exit 1
fi

# 2. Project name
FOLDER_NAME=$(basename "$PROJECT_ROOT")
read -rp "  Project name [$FOLDER_NAME]: " PROJECT_NAME
PROJECT_NAME="${PROJECT_NAME:-$FOLDER_NAME}"

# 3. Tech stack
DETECTED=""
[ -f "$PROJECT_ROOT/package.json" ] && DETECTED="Node.js"
[ -f "$PROJECT_ROOT/frontend/package.json" ] && DETECTED="Angular/React/Vue + $DETECTED"
find "$PROJECT_ROOT" -name "*.csproj" -maxdepth 4 2>/dev/null | head -1 | grep -q . && DETECTED="$DETECTED + .NET"
read -rp "  Tech stack [detected: ${DETECTED:-unknown}]: " TECH_STACK
TECH_STACK="${TECH_STACK:-$DETECTED}"

# 4. Architecture rules
echo ""
echo "  Enter architecture rules, one per line. Press Enter twice when done."
RULES=()
while IFS= read -rp "  Rule: " line && [ -n "$line" ]; do
  RULES+=("$line")
done

# 5. Golden modules
echo ""
read -rp "  Best SIMPLE CRUD reference file: " GOLDEN_SIMPLE
read -rp "  Best WIZARD/COMPLEX reference file (Enter to skip): " GOLDEN_WIZARD

# 6. Existing features
echo ""
read -rp "  Existing features (comma-separated): " FEATURES_RAW

# 7. Port
read -rp "  Chat server port [8765]: " PORT_INPUT
PORT="${PORT_INPUT:-8765}"

# 8. Memory dir
SAFE_SLUG=$(echo "$PROJECT_ROOT" | tr ':/\\ ' '----' | tr -s '-')
DEFAULT_MEM="$HOME/.claude/projects/$SAFE_SLUG/memory"
echo ""
read -rp "  AI memory dir [$DEFAULT_MEM]: " MEM_DIR
MEM_DIR="${MEM_DIR:-$DEFAULT_MEM}"
mkdir -p "$MEM_DIR"

# 9. Graph path
GRAPH_PATH="$PROJECT_ROOT/graphify-out/graph.json"

# Write config.json
RULES_JSON=$(printf '"%s",' "${RULES[@]}" | sed 's/,$//')
FEATURES_JSON=$(echo "$FEATURES_RAW" | python3 -c "import sys,json; items=[x.strip() for x in sys.stdin.read().split(',') if x.strip()]; print(json.dumps(items))" 2>/dev/null || echo "[]")

cat > "$HERE/config.json" <<EOF
{
  "projectName": "$PROJECT_NAME",
  "projectRoot": "$PROJECT_ROOT",
  "graphPath": "$GRAPH_PATH",
  "techStack": "$TECH_STACK",
  "backendPattern": "",
  "frontendPattern": "",
  "apiPattern": "/api/v1/<resource>",
  "architectureRules": [$RULES_JSON],
  "goldenModuleSimple": "$GOLDEN_SIMPLE",
  "goldenModuleWizard": "$GOLDEN_WIZARD",
  "existingFeatures": $FEATURES_JSON,
  "memoryDir": "$MEM_DIR",
  "port": $PORT
}
EOF
echo "  config.json written."

# Copy .graphifyignore
if [ ! -f "$PROJECT_ROOT/.graphifyignore" ]; then
  cp "$HERE/templates/graphifyignore" "$PROJECT_ROOT/.graphifyignore"
  echo "  .graphifyignore copied to project."
else
  echo "  .graphifyignore already exists (skipped)."
fi

# Copy workflows
mkdir -p "$PROJECT_ROOT/.claude/workflows"
for WF in update-project-memory.js feature-docs.js; do
  SRC="$HERE/workflows/$WF"
  DST="$PROJECT_ROOT/.claude/workflows/$WF"
  if [ -f "$SRC" ]; then
    ESC_ROOT=$(echo "$PROJECT_ROOT" | sed 's/\\/\\\\/g')
    ESC_MEM=$(echo "$MEM_DIR" | sed 's/\\/\\\\/g')
    sed -e "s|__PROJECT_ROOT__|$ESC_ROOT|g" \
        -e "s|__MEMORY_DIR__|$ESC_MEM|g" \
        -e "s|__PROJECT_NAME__|$PROJECT_NAME|g" \
        -e "s|__TECH_STACK__|$TECH_STACK|g" \
        "$SRC" > "$DST"
    echo "  Copied workflow: $WF"
  fi
done

# Build graph
echo ""
echo "  Building knowledge graph..."
cd "$PROJECT_ROOT"
if command -v graphify &>/dev/null; then
  graphify . --backend claude-cli
  echo "  Graph built."
else
  echo "  graphify not found. Install: uv tool install graphifyy && uv tool update-shell"
fi

# Write COMMANDS.md
TODAY=$(date +%Y-%m-%d)
cat > "$HERE/COMMANDS.md" <<EOF
# dev-assistant Commands for $PROJECT_NAME

## Start the chatbot
\`\`\`bash
python "$HERE/server.py"
\`\`\`
Open: http://localhost:$PORT

## Rebuild the knowledge graph
\`\`\`bash
cd "$PROJECT_ROOT"
graphify . --backend claude-cli
\`\`\`

## Update AI memory (full scan)
In Claude Code:
\`\`\`
Workflow({ name: 'update-project-memory', args: { date: '$TODAY' } })
\`\`\`

## Generate docs for one feature
In Claude Code:
\`\`\`
Workflow({ name: 'feature-docs', args: { feature: 'Your Feature Name', date: '$TODAY' } })
\`\`\`
EOF
echo "  COMMANDS.md written."

echo ""
echo "  Setup complete!"
echo "  Start: python \"$HERE/server.py\""
echo "  Open:  http://localhost:$PORT"
echo ""

#!/usr/bin/env bash
# dev-assistant — install prerequisites (Mac/Linux)
# Run once per machine before running connect.sh

set -e
echo ""
echo "  dev-assistant — install"
echo "  ----------------------------------------"
echo ""

# Python
if ! command -v python3 &>/dev/null; then
  echo "  Python 3 not found. Install from https://www.python.org/downloads/"
  exit 1
fi
echo "  Python: $(python3 --version)"

# Claude CLI
if command -v claude &>/dev/null; then
  echo "  Claude CLI: found"
else
  echo "  Claude CLI not found. Install Claude Code: https://claude.ai/code"
fi

# uv + graphify
if command -v uv &>/dev/null; then
  echo "  Installing graphify via uv..."
  uv tool install graphifyy
  uv tool update-shell
  echo "  graphify: installed"
else
  echo "  uv not found. Install it:"
  echo "    curl -LsSf https://astral.sh/uv/install.sh | sh"
  echo "  Then re-run this script."
  exit 1
fi

if command -v graphify &>/dev/null; then
  echo "  graphify: ready"
else
  echo "  graphify installed but not in PATH yet."
  echo "  Restart your terminal then run: ./connect.sh"
fi

echo ""
echo "  All prerequisites installed."
echo "  Next: ./connect.sh"
echo ""

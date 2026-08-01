#!/usr/bin/env bash
# dev-assistant — install prerequisites (Mac/Linux)

set -e
echo ""
echo "  dev-assistant — install"
echo "  ----------------------------------------"
echo ""

# Reload PATH (handles tools installed in same terminal session)
[ -f "$HOME/.local/bin/env" ]    && source "$HOME/.local/bin/env" 2>/dev/null || true
[ -f "$HOME/.cargo/env" ]        && source "$HOME/.cargo/env"     2>/dev/null || true
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

# Python
if command -v python3 &>/dev/null; then
  echo "  [OK] $(python3 --version)"
else
  echo "  [MISSING] Python 3 — install from https://www.python.org/"
  exit 1
fi

# Claude CLI
if command -v claude &>/dev/null; then
  echo "  [OK] Claude CLI found"
else
  echo "  [WARN] Claude CLI not found — install Claude Code: https://claude.ai/code"
fi

# uv — install if missing
if command -v uv; then
  echo "  [OK] uv found"
else
  echo "  [MISSING] uv not found. Installing..."
  curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="$HOME/.local/bin" sh
fi

if command -v uv; then
  echo "  [OK] uv found"
else
  echo "  [ERROR] uv install failed. Try manually: curl -LsSf https://astral.sh/uv/install.sh | sh"
  exit 1
fi

# graphify
echo "  Installing / updating graphify..."
uv tool install graphifyy || uv tool upgrade graphifyy || true
uv tool update-shell || true
export PATH="$HOME/.local/bin:$(uv tool dir 2>/dev/null)/bin:$PATH"

if command -v graphify &>/dev/null; then
  echo "  [OK] graphify ready"
else
  echo "  [WARN] graphify installed but PATH not updated — restart your terminal first."
fi

# docs export deps
echo "  Installing dependencies (markdown, xhtml2pdf, python-docx, watchdog)..."
python3 -m pip install markdown xhtml2pdf python-docx watchdog && echo "  [OK] docs export ready (PDF/DOCX)" \
  || echo "  [WARN] docs export deps failed to install — PDF/DOCX export won't work."

echo ""
echo "  Done. Next: ./connect.sh"
echo ""

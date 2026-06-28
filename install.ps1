# dev-assistant — install prerequisites (Windows)
# Run once per machine before running connect.ps1

Write-Host ""
Write-Host "  dev-assistant — install" -ForegroundColor Cyan
Write-Host "  ----------------------------------------"
Write-Host ""

# Check Python
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "  Python not found. Install from https://www.python.org/downloads/" -ForegroundColor Red
    exit 1
}
$pyVer = python --version 2>&1
Write-Host "  Python: $pyVer" -ForegroundColor Green

# Check Claude CLI
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "  Claude CLI not found." -ForegroundColor Yellow
    Write-Host "  Install Claude Code: https://claude.ai/code" -ForegroundColor Yellow
} else {
    Write-Host "  Claude CLI: found" -ForegroundColor Green
}

# Install / update graphify
if (Get-Command uv -ErrorAction SilentlyContinue) {
    Write-Host "  Installing graphify via uv..." -ForegroundColor Cyan
    uv tool install graphifyy 2>&1 | Out-Null
    uv tool update-shell 2>&1 | Out-Null
    Write-Host "  graphify: installed" -ForegroundColor Green
} else {
    Write-Host "  uv not found. Install uv first:" -ForegroundColor Yellow
    Write-Host "    winget install astral-sh.uv" -ForegroundColor Yellow
    Write-Host "  Then re-run this script." -ForegroundColor Yellow
    exit 1
}

# Verify graphify
if (Get-Command graphify -ErrorAction SilentlyContinue) {
    Write-Host "  graphify: ready" -ForegroundColor Green
} else {
    Write-Host "  graphify installed but not in PATH yet." -ForegroundColor Yellow
    Write-Host "  Open a new terminal and re-run connect.ps1." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  All prerequisites installed." -ForegroundColor Green
Write-Host "  Next: run .\connect.ps1 to connect to your project."
Write-Host ""

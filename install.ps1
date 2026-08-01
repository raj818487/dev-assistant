# dev-assistant — install prerequisites (Windows)
# Run once per machine.

Write-Host ""
Write-Host "  dev-assistant — install" -ForegroundColor Cyan
Write-Host "  ----------------------------------------"
Write-Host ""

# Refresh PATH from registry so tools installed in this session are visible
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("PATH","User")

# ── Python ────────────────────────────────────────────────────────────────────
$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) {
    Write-Host "  [MISSING] Python — install from https://www.python.org/downloads/" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] $(python --version 2>&1)" -ForegroundColor Green

# ── Claude CLI ────────────────────────────────────────────────────────────────
$cl = Get-Command claude -ErrorAction SilentlyContinue
if ($cl) {
    Write-Host "  [OK] Claude CLI found at $($cl.Source)" -ForegroundColor Green
} else {
    Write-Host "  [WARN] Claude CLI not found — install Claude Code from https://claude.ai/code" -ForegroundColor Yellow
}

# ── uv ────────────────────────────────────────────────────────────────────────
# Check PATH first, then fall back to known install locations
$uvCmd = Get-Command uv -ErrorAction SilentlyContinue
if (-not $uvCmd) {
    $candidates = @(
        "$env:USERPROFILE\.local\bin\uv.exe",
        "$env:USERPROFILE\.cargo\bin\uv.exe",
        "$env:LOCALAPPDATA\uv\uv.exe",
        "$env:LOCALAPPDATA\Programs\uv\uv.exe",
        "C:\Program Files\uv\uv.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $uvCmd = $c; break }
    }
}

if (-not $uvCmd) {
    Write-Host "  [MISSING] uv not found. Installing via winget..." -ForegroundColor Yellow
    winget install astral-sh.uv --silent 2>&1 | Out-Null
    # Refresh PATH again after install
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH","User")
    $uvCmd = Get-Command uv -ErrorAction SilentlyContinue
    if (-not $uvCmd) {
        Write-Host "  [WARN] uv installed but not in PATH yet. Open a new terminal and re-run." -ForegroundColor Yellow
        exit 1
    }
}
Write-Host "  [OK] uv found" -ForegroundColor Green

# ── graphify ──────────────────────────────────────────────────────────────────
Write-Host "  Installing / updating graphify..." -ForegroundColor Cyan
$uvExe = if ($uvCmd -is [string]) { $uvCmd } else { $uvCmd.Source }
& $uvExe tool install graphifyy 2>&1 | Out-Null
& $uvExe tool update-shell 2>&1 | Out-Null

# Refresh PATH one more time
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("PATH","User")

$gf = Get-Command graphify -ErrorAction SilentlyContinue
if ($gf) {
    Write-Host "  [OK] graphify ready at $($gf.Source)" -ForegroundColor Green
} else {
    Write-Host "  [WARN] graphify installed but not in PATH. Open a new terminal." -ForegroundColor Yellow
}

# ── PDF/DOCX export deps ────────────────────────────────────────────────────
Write-Host "  Installing dependencies (markdown, xhtml2pdf, python-docx, watchdog)..." -ForegroundColor Cyan
python -m pip install --quiet markdown xhtml2pdf python-docx watchdog
if ($?) {
    Write-Host "  [OK] docs export ready (PDF/DOCX)" -ForegroundColor Green
} else {
    Write-Host "  [WARN] docs export deps failed to install — PDF/DOCX export won't work." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Done. Next step: .\connect.ps1" -ForegroundColor Green
Write-Host ""


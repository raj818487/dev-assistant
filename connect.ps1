# dev-assistant — connect to a project
# Usage: .\connect.ps1
# Run once per project. Generates config.json and installs files into the target project.

Set-StrictMode -Off
$ErrorActionPreference = "Stop"
$HERE = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "  dev-assistant — connect to a project" -ForegroundColor Cyan
Write-Host "  ----------------------------------------"
Write-Host ""

# ── 1. Project root ───────────────────────────────────────────────────────────
$projectRoot = Read-Host "  Project root path (absolute)"
$projectRoot = $projectRoot.Trim().Trim('"')
if (-not (Test-Path $projectRoot)) {
    Write-Host "  ERROR: Path not found: $projectRoot" -ForegroundColor Red
    exit 1
}

# ── 2. Project name ───────────────────────────────────────────────────────────
$folderName = Split-Path -Leaf $projectRoot
$projectName = Read-Host "  Project name [$folderName]"
if ([string]::IsNullOrWhiteSpace($projectName)) { $projectName = $folderName }

# ── 3. Tech stack (auto-detect or ask) ───────────────────────────────────────
$detectedStack = ""
if (Test-Path "$projectRoot\package.json") {
    $pkg = Get-Content "$projectRoot\package.json" -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
    $fw = $pkg.dependencies.PSObject.Properties.Name -join ", "
    $detectedStack = "Node.js / $fw"
}
if (Test-Path "$projectRoot\frontend\package.json") {
    $pkg = Get-Content "$projectRoot\frontend\package.json" -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($pkg.dependencies."@angular/core") { $detectedStack = "Angular + " + $detectedStack }
    if ($pkg.dependencies."react")         { $detectedStack = "React + "   + $detectedStack }
    if ($pkg.dependencies."vue")           { $detectedStack = "Vue + "     + $detectedStack }
}
if (Get-ChildItem "$projectRoot" -Recurse -Filter "*.csproj" -ErrorAction SilentlyContinue | Select-Object -First 1) {
    $detectedStack = $detectedStack + " .NET"
}
$hint = if ($detectedStack) { " [detected: $($detectedStack.Trim(' +'))]" } else { "" }
$techStack = Read-Host "  Tech stack$hint"
if ([string]::IsNullOrWhiteSpace($techStack)) { $techStack = $detectedStack.Trim(' +') }

# ── 4. Architecture rules ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Enter your top architecture rules, one per line." -ForegroundColor Yellow
Write-Host "  (e.g. 'Never add a second DbContext', 'Always use null for optional numbers')"
Write-Host "  Press Enter twice when done."
$rules = @()
while ($true) {
    $line = Read-Host "  Rule"
    if ([string]::IsNullOrWhiteSpace($line)) { break }
    $rules += $line
}

# ── 5. Golden modules ─────────────────────────────────────────────────────────
Write-Host ""
$goldenSimple = Read-Host "  Best SIMPLE CRUD reference file (e.g. src/controllers/cities.controller.ts)"
$goldenWizard = Read-Host "  Best WIZARD/COMPLEX reference file (Enter to skip)"

# ── 6. Existing features ──────────────────────────────────────────────────────
Write-Host ""
Write-Host "  List existing features (comma-separated, or press Enter to skip):" -ForegroundColor Yellow
$featuresRaw = Read-Host "  Features"
$features = if ($featuresRaw) { $featuresRaw -split "," | ForEach-Object { $_.Trim() } } else { @() }

# ── 7. Port ───────────────────────────────────────────────────────────────────
$portStr = Read-Host "  Chat server port [8765]"
$port = if ($portStr -match '^\d+$') { [int]$portStr } else { 8765 }

# ── 8. Memory dir (for AI context workflows) ──────────────────────────────────
$safeSlug = $projectRoot -replace '[:\\/ ]', '-' -replace '-+', '-'
$defaultMemDir = "$env:USERPROFILE\.claude\projects\$safeSlug\memory"
Write-Host ""
Write-Host "  AI memory dir (stores Claude context files)" -ForegroundColor Yellow
$memDir = Read-Host "  Memory dir [$defaultMemDir]"
if ([string]::IsNullOrWhiteSpace($memDir)) { $memDir = $defaultMemDir }
New-Item -ItemType Directory -Force -Path $memDir | Out-Null

# ── 9. Graph path ─────────────────────────────────────────────────────────────
$graphPath = "$projectRoot\graphify-out\graph.json"

# ── Write config.json ─────────────────────────────────────────────────────────
$config = [ordered]@{
    projectName     = $projectName
    projectRoot     = $projectRoot
    graphPath       = $graphPath
    techStack       = $techStack
    backendPattern  = ""
    frontendPattern = ""
    apiPattern      = "/api/v1/<resource>"
    architectureRules = $rules
    goldenModuleSimple = $goldenSimple
    goldenModuleWizard = $goldenWizard
    existingFeatures   = $features
    memoryDir = $memDir
    port      = $port
}
$config | ConvertTo-Json -Depth 5 | Set-Content "$HERE\config.json" -Encoding UTF8
Write-Host ""
Write-Host "  config.json written." -ForegroundColor Green

# ── Copy .graphifyignore to project ──────────────────────────────────────────
$ignoreTemplate = "$HERE\templates\graphifyignore"
$ignoreTarget   = "$projectRoot\.graphifyignore"
if (-not (Test-Path $ignoreTarget)) {
    Copy-Item $ignoreTemplate $ignoreTarget
    Write-Host "  .graphifyignore copied to project." -ForegroundColor Green
} else {
    Write-Host "  .graphifyignore already exists in project (skipped)." -ForegroundColor Yellow
}

# ── Copy workflows to project ─────────────────────────────────────────────────
$wfDir = "$projectRoot\.claude\workflows"
New-Item -ItemType Directory -Force -Path $wfDir | Out-Null

$configForWf = $config | ConvertTo-Json -Depth 5 -Compress

foreach ($wf in @("update-project-memory.js", "feature-docs.js")) {
    $src = "$HERE\workflows\$wf"
    $dst = "$wfDir\$wf"
    if (Test-Path $src) {
        $content = Get-Content $src -Raw
        # Inject config values into the workflow
        $content = $content -replace '__PROJECT_ROOT__', ($projectRoot -replace '\\', '\\\\')
        $content = $content -replace '__MEMORY_DIR__', ($memDir -replace '\\', '\\\\')
        $content = $content -replace '__PROJECT_NAME__', $projectName
        $content = $content -replace '__TECH_STACK__', $techStack
        Set-Content $dst $content -Encoding UTF8
        Write-Host "  Copied workflow: $wf" -ForegroundColor Green
    }
}

# ── Build the graph ───────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Building knowledge graph (this takes a few minutes)..." -ForegroundColor Cyan
$graphifyArgs = ". --backend claude-cli"
$ignoreFile = "$projectRoot\.graphifyignore"
Set-Location $projectRoot
try {
    & graphify . --backend claude-cli
    Write-Host "  Graph built." -ForegroundColor Green
} catch {
    Write-Host "  graphify not found. Install it first: uv tool install graphifyy" -ForegroundColor Red
    Write-Host "  Then re-run: .\connect.ps1" -ForegroundColor Yellow
}

# ── Write COMMANDS.md with pre-filled commands ────────────────────────────────
$commandsMd = @"
# dev-assistant Commands for $projectName

Generated by connect.ps1.

## Start the chatbot

``````powershell
python "$HERE\server.py"
``````
Open: http://localhost:$port

## Regenerate the knowledge graph

``````powershell
cd "$projectRoot"
graphify . --backend claude-cli
``````

## Update AI memory (full project scan)

In Claude Code:
``````
Workflow({ name: 'update-project-memory', args: { date: '$(Get-Date -Format yyyy-MM-dd)' } })
``````

## Generate docs for one feature

In Claude Code:
``````
Workflow({ name: 'feature-docs', args: { feature: 'Your Feature Name', date: '$(Get-Date -Format yyyy-MM-dd)' } })
``````
"@
Set-Content "$HERE\COMMANDS.md" $commandsMd -Encoding UTF8
Write-Host "  COMMANDS.md written with pre-filled commands." -ForegroundColor Green

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Start the assistant:   python `"$HERE\server.py`""
Write-Host "  Open browser:          http://localhost:$port"
Write-Host "  All commands:          $HERE\COMMANDS.md"
Write-Host ""

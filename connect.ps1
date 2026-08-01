# dev-assistant — connect to a project (Windows)
# Ask: project path + tech stack. Everything else is auto-detected.
# Usage: .\connect.ps1

Set-StrictMode -Off
$ErrorActionPreference = "Stop"
if ($scriptPath) {
    $HERE = Split-Path -Parent $scriptPath
} else {
    $HERE = Split-Path -Parent $MyInvocation.MyCommand.Path
}

# Refresh PATH so graphify / claude / uv are visible even if just installed
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("PATH","User")

Write-Host ""
Write-Host "  dev-assistant — connect" -ForegroundColor Cyan
Write-Host "  ----------------------------------------"
Write-Host ""

# ── 1. Two questions ──────────────────────────────────────────────────────────
$projectRoot = (Read-Host "  Project path (absolute)").Trim().Trim('"')
if (-not (Test-Path $projectRoot)) {
    Write-Host "  ERROR: path not found." -ForegroundColor Red; exit 1
}

$folderName  = Split-Path -Leaf $projectRoot
$techStack   = Read-Host "  Tech stack (e.g. 'Angular + .NET + PostgreSQL')"
$projectName = $folderName   # derived — user can edit config.json later if needed

$portStr = Read-Host "  Chat server port [8765]"
$port    = if ($portStr -match "^\d+$") { [int]$portStr } else { 8765 }

Write-Host ""
Write-Host "  Got it. Auto-detecting the rest from your codebase..." -ForegroundColor Cyan

# ── 2. Check graphify ─────────────────────────────────────────────────────────
$gfCmd = Get-Command graphify -ErrorAction SilentlyContinue
if (-not $gfCmd) {
    Write-Host ""
    Write-Host "  graphify not found. Run .\install.ps1 first." -ForegroundColor Red
    exit 1
}

# ── 3. Build knowledge graph ──────────────────────────────────────────────────
Write-Host "  [1/4] Building knowledge graph (may take 2-5 min)..." -ForegroundColor Yellow
Push-Location $projectRoot
try {
    & graphify . --backend claude-cli
    Write-Host "  Graph built." -ForegroundColor Green
} catch {
    Write-Host "  Graph build failed: $_" -ForegroundColor Red
    Write-Host "  Continuing with partial config — you can rebuild later." -ForegroundColor Yellow
}
Pop-Location

$graphPath = "$projectRoot\graphify-out\graph.json"

# ── 4. Auto-detect config using Claude ───────────────────────────────────────
Write-Host "  [2/4] Auto-detecting project config with Claude..." -ForegroundColor Yellow

$autoPrompt = @"
You are analysing a software project to configure an AI assistant.

Project path: $projectRoot
Tech stack: $techStack

Scan the project directory. Look at:
- CLAUDE.md, AGENTS.md, README.md for architecture rules
- Backend controllers/routes to find existing features and API patterns
- Frontend pages/components to find existing features
- The simplest complete CRUD file (smallest controller+service pair) as the golden simple module
- The most complex multi-step form/wizard as the golden wizard module

Return ONLY a valid JSON object, no markdown, no explanation, nothing else:
{
  "architectureRules": ["rule 1", "rule 2", "rule 3"],
  "existingFeatures": ["Feature A", "Feature B"],
  "goldenModuleSimple": "relative/path/to/simplest/crud/file",
  "goldenModuleWizard": "relative/path/to/wizard/file or empty string",
  "apiPattern": "/api/v1/<resource> or detected pattern",
  "backendPattern": "one sentence about backend layer structure",
  "frontendPattern": "one sentence about frontend component structure"
}
"@

$autoConfig = $null
try {
    $tmpFile = [System.IO.Path]::GetTempFileName()
    $autoPrompt | Out-File $tmpFile -Encoding UTF8
    $raw = Get-Content $tmpFile | & claude --print 2>&1
    Remove-Item $tmpFile -ErrorAction SilentlyContinue

    # Extract the JSON block from the response
    $jsonMatch = [regex]::Match($raw, "(?s)\{.*\}")
    if ($jsonMatch.Success) {
        $autoConfig = $jsonMatch.Value | ConvertFrom-Json
        Write-Host "  Auto-detection complete." -ForegroundColor Green
    } else {
        Write-Host "  Auto-detection returned unexpected output. Using defaults." -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Auto-detection failed: $_" -ForegroundColor Yellow
    Write-Host "  Using defaults — edit config.json manually if needed." -ForegroundColor Yellow
}

# ── 5. Build config.json ──────────────────────────────────────────────────────
Write-Host "  [3/4] Writing config.json..." -ForegroundColor Yellow

$safeSlug   = $projectRoot -replace "[^a-zA-Z0-9]", "-" -replace "-+", "-"
$memDir     = "$env:USERPROFILE\.claude\projects\$safeSlug\memory"
New-Item -ItemType Directory -Force -Path $memDir | Out-Null

$baseRules = if ($autoConfig) { @($autoConfig.architectureRules) } else { @() }
$mandatoryRules = @(
    "NEVER_BREAK_EXISTING_FUNCTIONALITY: Every code change must preserve existing working behavior, preserve public API contracts/signatures, and pass graphify regression checks before finishing.",
    "ALWAYS_VERIFY_LATEST_CONTEXT: AI agents must query the latest graphify codebase graph and inspect dependent modules before modifying files.",
    "SENIOR_ENGINEER_SURGICAL_EDITS: Write code like a 10+ year senior engineer in the language—make minimal surgical edits, maximize reuse of existing project utilities, and avoid unnecessary refactoring."
)
$archRules = $baseRules + $mandatoryRules

$config = [ordered]@{
    projectName        = $projectName
    projectRoot        = $projectRoot
    graphPath          = $graphPath
    techStack          = $techStack
    backendPattern     = if ($autoConfig) { $autoConfig.backendPattern }  else { "" }
    frontendPattern    = if ($autoConfig) { $autoConfig.frontendPattern } else { "" }
    apiPattern         = if ($autoConfig) { $autoConfig.apiPattern }      else { "/api/v1/<resource>" }
    architectureRules  = $archRules
    goldenModuleSimple = if ($autoConfig) { $autoConfig.goldenModuleSimple } else { "" }
    goldenModuleWizard = if ($autoConfig) { $autoConfig.goldenModuleWizard } else { "" }
    existingFeatures   = if ($autoConfig) { @($autoConfig.existingFeatures) } else { @() }
    memoryDir          = $memDir
    port               = $port
}

$config | ConvertTo-Json -Depth 5 | Set-Content "$projectRoot\dev-assistant.json" -Encoding UTF8
Write-Host "  dev-assistant.json written to project." -ForegroundColor Green

# ── 6. Copy templates + workflows into project ────────────────────────────────
Write-Host "  [4/4] Installing files into project..." -ForegroundColor Yellow

# .graphifyignore
if (-not (Test-Path "$projectRoot\.graphifyignore")) {
    Copy-Item "$HERE\templates\graphifyignore" "$projectRoot\.graphifyignore"
    Write-Host "  .graphifyignore installed." -ForegroundColor Green
}

# Auto-Gitignore
$gitIgnorePath = "$projectRoot\.gitignore"
$aiIgnores = "`n# --- AI & dev-assistant ignores ---`ngraphify-out/`n.claude/projects/`n"
if (Test-Path $gitIgnorePath) {
    $content = Get-Content $gitIgnorePath -Raw
    if (-not ($content -match "graphify-out")) {
        Add-Content $gitIgnorePath $aiIgnores
        Write-Host "  .gitignore updated with AI ignores." -ForegroundColor Green
    }
} else {
    Set-Content $gitIgnorePath $aiIgnores
    Write-Host "  .gitignore created with AI ignores." -ForegroundColor Green
}

# Git Hook Installer
$gitHooksDir = "$projectRoot\.git\hooks"
if (Test-Path $gitHooksDir) {
    $hookScript = "#!/bin/sh`ngraphify . --backend claude-cli > /dev/null 2>&1 &`n"
    foreach ($hook in @("post-merge", "post-checkout")) {
        $hookPath = "$gitHooksDir\$hook"
        if (-not (Test-Path $hookPath)) {
            Set-Content $hookPath $hookScript
            Write-Host "  Git hook installed: $hook" -ForegroundColor Green
        }
    }
}

# docs_export.py (PDF / DOCX export for generated docs)
Copy-Item "$HERE\docs_export.py" "$projectRoot\docs_export.py" -Force
Write-Host "  docs_export.py installed." -ForegroundColor Green

# Workflows
$wfDir = "$projectRoot\.claude\workflows"
New-Item -ItemType Directory -Force -Path $wfDir | Out-Null

foreach ($wf in @("update-project-memory.js", "feature-docs.js")) {
    $src = "$HERE\workflows\$wf"
    $dst = "$wfDir\$wf"
    if (Test-Path $src) {
        $c = Get-Content $src -Raw
        $c = $c -replace "__PROJECT_ROOT__", ($projectRoot  -replace "\\", "\\\\")
        $c = $c -replace "__MEMORY_DIR__",   ($memDir       -replace "\\", "\\\\")
        $c = $c -replace "__PROJECT_NAME__", $projectName
        $c = $c -replace "__TECH_STACK__",   $techStack
        Set-Content $dst $c -Encoding UTF8
        Write-Host "  Workflow installed: $wf" -ForegroundColor Green
    }
}

# Skills (e.g. grill-me, context-loader, pattern-clone, db-design, code-review-quality, test-agent)
$skillsSrcDir = "$HERE\skills"
if (Test-Path $skillsSrcDir) {
    foreach ($skillDir in Get-ChildItem $skillsSrcDir -Directory) {
        $dst = "$projectRoot\.claude\skills\$($skillDir.Name)"
        New-Item -ItemType Directory -Force -Path $dst | Out-Null
        Copy-Item "$($skillDir.FullName)\*" $dst -Recurse -Force
        Write-Host "  Skill installed: $($skillDir.Name)" -ForegroundColor Green
    }

    # Fan out the same skills to Cursor / Copilot / Gemini / Codex
    & python "$HERE\generate_agent_adapters.py" --project-root "$projectRoot" 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    Write-Host "  Agent adapters generated (Cursor, Copilot, Gemini, Codex)." -ForegroundColor Green
}

# ── 7. Write COMMANDS.md ──────────────────────────────────────────────────────
$today = Get-Date -Format "yyyy-MM-dd"
$cmdsMd = @"
# dev-assistant commands for $projectName

## Start the chatbot
``````powershell
cd "$HERE"
python server.py
``````
Open: http://localhost:$port

## Rebuild the graph (after big code changes)
``````powershell
cd "$projectRoot"
graphify . --backend claude-cli
``````

## Update AI memory (in Claude Code chat)
``````
Workflow({ name: "update-project-memory", args: { date: "$today" } })
``````

## Generate feature docs (in Claude Code chat)
``````
Workflow({ name: "feature-docs", args: { feature: "Your Feature Name", date: "$today" } })
``````

## Export generated docs as PDF / DOCX
``````powershell
cd "$projectRoot"
python docs_export.py "docs/specs/<feature-slug>-*.md" --formats pdf,docx
``````

## Installed Claude Code skills
grill-me, context-loader, pattern-clone, db-design, code-review-quality, test-agent
(auto-discovered from ``.claude\skills\`` — no slash command needed, Claude decides when to use them)

## Re-generate Cursor / Copilot / Gemini / Codex adapters
(run after editing any skill under ``.claude\skills\``)
``````powershell
cd "$HERE"
python generate_agent_adapters.py --project-root "$projectRoot"
``````
"@
Set-Content "$HERE\COMMANDS.md" $cmdsMd -Encoding UTF8

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  All done!" -ForegroundColor Green
Write-Host ""
Write-Host "  Start the assistant:" -ForegroundColor Cyan
Write-Host "    npx dev-assistant serve" -ForegroundColor White
Write-Host ""
Write-Host "  Open in browser: http://localhost:$port" -ForegroundColor Cyan
Write-Host ""
if ($autoConfig -and $autoConfig.existingFeatures) {
    Write-Host "  Detected $($autoConfig.existingFeatures.Count) existing features." -ForegroundColor DarkGray
}
Write-Host "  Edit $projectRoot\dev-assistant.json to adjust if anything looks wrong." -ForegroundColor DarkGray
Write-Host ""

#!/usr/bin/env node

const { execSync } = require('child_process');
const path = require('path');
const os = require('os');

const fs = require('fs');

const isWindows = os.platform() === 'win32';
const rootDir = __dirname;


try {
  if (process.argv[2] === 'serve') {
    console.log("Starting Omni-Plugin Chat Server...");
    const serverScript = path.join(rootDir, 'server.py');
    execSync(`python "${serverScript}"`, { stdio: 'inherit', cwd: process.cwd() });
    process.exit(0);
  }

  if (process.argv[2] === 'graphify' || process.argv[2] === 'update-graph') {
    console.log("Updating graphify codebase knowledge graph...");
    const graphPath = path.join(process.cwd(), 'graphify-out', 'graph.json');
    try {
      execSync(`graphify extract . --backend claude-cli`, { stdio: 'inherit', cwd: process.cwd() });
    } catch (e) {
      // Check if AST already produced a partial graph (common when only semantic LLM fails)
      if (fs.existsSync(graphPath)) {
        console.log("  [OK] Partial AST graph exists — skipping fallback.");
      } else {
        console.log("  [WARN] No graph produced. Falling back to AST-only (no LLM needed)...");
        execSync(`graphify extract . --code-only`, { stdio: 'inherit', cwd: process.cwd() });
      }
    }
    console.log("  Graph ready.");
    process.exit(0);
  }

  if (process.argv[2] === 'graphify-tree') {
    console.log("Generating interactive HTML tree map of the codebase...");
    execSync(`graphify tree`, { stdio: 'inherit', cwd: process.cwd() });
    process.exit(0);
  }

  if (process.argv[2] === 'graphify-callflow') {
    console.log("Generating Mermaid architecture call-flow HTML...");
    execSync(`graphify export callflow-html`, { stdio: 'inherit', cwd: process.cwd() });
    process.exit(0);
  }

  console.log("Installing omni-plugin...");
  
  if (isWindows) {
    const installScript = path.join(rootDir, 'install.ps1');
    const connectScript = path.join(rootDir, 'connect.ps1');
    execSync(`powershell -ExecutionPolicy Bypass -Command "Invoke-Expression ([System.IO.File]::ReadAllText('${installScript}', [System.Text.Encoding]::UTF8))"`, { stdio: 'inherit' });
    execSync(`powershell -ExecutionPolicy Bypass -Command "$scriptPath='${connectScript}'; Invoke-Expression ([System.IO.File]::ReadAllText($scriptPath, [System.Text.Encoding]::UTF8))"`, { stdio: 'inherit' });
  } else {
    const installScript = path.join(rootDir, 'install.sh');
    const connectScript = path.join(rootDir, 'connect.sh');
    execSync(`bash "${installScript}"`, { stdio: 'inherit' });
    execSync(`bash "${connectScript}"`, { stdio: 'inherit' });
  }
  
  console.log("Done! AI adapters generated successfully.");
} catch (error) {
  console.error("Failed to run omni-plugin installer.", error.message);
  process.exit(1);
}

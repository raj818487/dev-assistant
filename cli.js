#!/usr/bin/env node

const { execSync } = require('child_process');
const path = require('path');
const os = require('os');

const isWindows = os.platform() === 'win32';
const rootDir = __dirname;

try {
  console.log("Installing dev-assistant...");
  
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
  console.error("Failed to run dev-assistant installer.", error.message);
  process.exit(1);
}

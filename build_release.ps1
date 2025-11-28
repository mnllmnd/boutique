#!/usr/bin/env pwsh
# Flutter Build Script for Boutique App

$projectPath = "c:\Users\bmd-tech\Desktop\Boutique\mobile"
$logFile = Join-Path $projectPath "build_log_release.txt"

Write-Host "🚀 Starting Flutter Release Build..." -ForegroundColor Cyan
Write-Host "📁 Project: $projectPath" -ForegroundColor Gray
Write-Host "📝 Log file: $logFile" -ForegroundColor Gray
Write-Host ""

Push-Location $projectPath

# Run the build and capture output
Write-Host "⏳ Building appbundle..." -ForegroundColor Yellow
$sw = [System.Diagnostics.Stopwatch]::StartNew()

flutter build appbundle --release 2>&1 | Tee-Object -FilePath $logFile

$sw.Stop()
$minutes = $sw.Elapsed.Minutes
$seconds = $sw.Elapsed.Seconds

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host "⏱️  Build time: ${minutes}m ${seconds}s" -ForegroundColor Green
    Write-Host "📦 Output: $(Join-Path $projectPath "build\app\outputs\bundle\release\app-release.aab")" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "❌ BUILD FAILED" -ForegroundColor Red
    Write-Host "⏱️  Build time: ${minutes}m ${seconds}s" -ForegroundColor Red
    Write-Host "📋 Check log: $logFile" -ForegroundColor Red
}

Pop-Location
exit $LASTEXITCODE

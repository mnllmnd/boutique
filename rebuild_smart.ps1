#!/usr/bin/env pwsh

Write-Host "🔴 Killing all build processes..." -ForegroundColor Red
Get-Process | Where-Object {$_.ProcessName -match 'java|dart|gradle|flutter|python'} | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

$projectPath = "c:\Users\bmd-tech\Desktop\Boutique\mobile"
Write-Host "📁 Cleaning build directories..." -ForegroundColor Yellow

# Remove with retry logic
$retries = 3
for ($i = 0; $i -lt $retries; $i++) {
    try {
        Remove-Item -Path "$projectPath\build" -Recurse -Force -ErrorAction Stop | Out-Null
        Remove-Item -Path "$projectPath\.dart_tool" -Recurse -Force -ErrorAction Stop | Out-Null
        Remove-Item -Path "$projectPath\android\.gradle" -Recurse -Force -ErrorAction Stop | Out-Null
        break
    }
    catch {
        Write-Host "  Attempt $($i+1)/$retries failed, retrying..." -ForegroundColor Gray
        Start-Sleep -Seconds 2
    }
}

Write-Host "✅ Directories cleaned" -ForegroundColor Green
Write-Host "📦 Getting Flutter dependencies..." -ForegroundColor Yellow
Push-Location $projectPath
& flutter pub get

Write-Host "🔨 Building release bundle..." -ForegroundColor Yellow
& flutter build appbundle --release

Write-Host "✨ Build complete!" -ForegroundColor Green
Pop-Location

@echo off
REM Restart Backend Server and Verify Guest Creation

echo.
echo ========================================
echo   BOUTIQUE BACKEND - RESTART & DIAGNOSE
echo ========================================
echo.

REM Kill any existing node process
echo 🔧 Killing existing Node.js processes...
taskkill /IM node.exe /F /T 2>nul
if %ERRORLEVEL% EQU 0 (
    echo ✅ Processes killed
) else (
    echo ℹ️  No existing processes
)

REM Wait for cleanup
timeout /t 2 /nobreak

REM Navigate to backend
cd /d C:\Users\bmd-tech\Desktop\Boutique\backend

REM Start server
echo.
echo 🚀 Starting backend server...
echo ========================================
start "Boutique Backend" cmd /k npm start

REM Wait for server to start
echo.
echo ⏳ Waiting for server to start (5 seconds)...
timeout /t 5 /nobreak

REM Test endpoints
echo.
echo 🧪 Testing endpoints...
echo ========================================

echo.
echo 1️⃣  Testing: GET /api/auth/health
powershell -Command "try { $r = Invoke-WebRequest -Uri 'http://localhost:3000/api/auth/health' -ErrorAction Stop; Write-Host '✅ Status: '$r.StatusCode; Write-Host '📝 Response: '$r.Content } catch { Write-Host '❌ Error: '$_.Exception.Response.StatusCode }"

echo.
echo 2️⃣  Testing: GET /api/auth/debug/schema
powershell -Command "try { $r = Invoke-WebRequest -Uri 'http://localhost:3000/api/auth/debug/schema' -ErrorAction Stop; Write-Host '✅ Status: '$r.StatusCode; $content = $r.Content | ConvertFrom-Json; Write-Host 'is_guest column exists: '$content.has_is_guest } catch { Write-Host '❌ Error: '$_.Exception.Response.StatusCode }"

echo.
echo 3️⃣  Testing: POST /api/auth/create-guest
powershell -Command "try { $r = Invoke-WebRequest -Uri 'http://localhost:3000/api/auth/create-guest' -Method POST -ContentType 'application/json' -Body '{}' -ErrorAction Stop; Write-Host '✅ Status: '$r.StatusCode; $content = $r.Content | ConvertFrom-Json; Write-Host 'Guest created: '$content.guest.phone } catch { Write-Host '❌ Status: '$_.Exception.Response.StatusCode; Write-Host 'Message: '$_.Exception.Response }"

echo.
echo 4️⃣  Listing all guests
powershell -Command "try { $r = Invoke-WebRequest -Uri 'http://localhost:3000/api/auth/guests' -ErrorAction Stop; Write-Host '✅ Status: '$r.StatusCode; $content = $r.Content | ConvertFrom-Json; Write-Host 'Total guests: '$content.count; foreach ($guest in $content.guests) { Write-Host ('  - ' + $guest.phone + ' (is_guest=' + $guest.is_guest + ')') } } catch { Write-Host '❌ Error: '$_.Exception.Response.StatusCode }"

echo.
echo ========================================
echo ✅ Diagnostics complete!
echo ========================================
echo.
echo The backend server is now running in a separate window.
echo Check the server window for logs during app testing.
echo.
pause

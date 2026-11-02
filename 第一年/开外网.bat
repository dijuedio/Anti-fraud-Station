@echo off
cd /d "%~dp0"
title First Year - Public Link

rem ---- 1) local server ----
curl -s -o nul --max-time 2 http://127.0.0.1:8000/ >nul 2>&1
if errorlevel 1 (
  echo [1/3] starting server on 8000 ...
  start "" /min cmd /c "python server.py > data\server.out 2>&1"
  timeout /t 5 >nul
) else (
  echo [1/3] local 8000 already running
)

rem ---- 2) tunnel ----
echo [2/3] opening tunnel ...
if exist tunnel.log del tunnel.log >nul 2>&1
start "" /min cmd /c "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=known_hosts -o ServerAliveInterval=20 -o ExitOnForwardFailure=yes -R 80:127.0.0.1:8000 nokey@localhost.run > tunnel.log 2>&1"

rem ---- 3) wait for the url (up to 70s) ----
echo [3/3] waiting for address ...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$u=''; for($i=0;$i -lt 35;$i++){ Start-Sleep -Seconds 2; $m = Select-String -Path 'tunnel.log' -Pattern 'https://[a-z0-9-]+\.lhr\.life' -AllMatches -ErrorAction SilentlyContinue; if($m){ $u = ($m | ForEach-Object { $_.Matches.Value } | Select-Object -Last 1); break } }; if($u){ Set-Clipboard -Value $u; Write-Host ''; Write-Host ('  YOUR LINK:  ' + $u) -ForegroundColor Green; Write-Host '  (copied to clipboard)' } else { Write-Host '  no address yet - double-click this file again in 10s, or read tunnel.log' -ForegroundColor Yellow }"

echo.
echo Keep the minimized ssh window open. Close it = link dies.
pause

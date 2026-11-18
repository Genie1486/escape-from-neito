@echo off
cd /d "%~dp0"
title Codyssey LibreChat Cleanup and Exit

echo ====================================================
echo   Stopping LibreChat and Wiping Sensitive Data
echo ====================================================

if not exist "LibreChat" goto SKIP_DOCKER

echo [1/4] Stopping Docker containers and removing volumes...
cd LibreChat
docker compose down -v
cd ..

echo [2/4] Deleting LibreChat folder completely...
rmdir /s /q LibreChat
goto CLEAR_CLIPBOARD

:SKIP_DOCKER
echo [INFO] LibreChat folder already removed.

:CLEAR_CLIPBOARD
echo [3/4] Clearing Windows clipboard and history...
echo off | clip
powershell -NoProfile -Command "[Windows.ApplicationModel.DataTransfer.Clipboard, Windows, ContentType = WindowsRuntime]::ClearHistory()" >nul 2>nul

echo [4/4] Clearing memory variables...
set ANTHROPIC_KEY=
set OPENAI_KEY=

echo ====================================================
echo   CLEANUP COMPLETE! Safe to leave the classroom PC.
echo ====================================================
pause
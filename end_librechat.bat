@echo off
cd /d "%~dp0"
title Codyssey LibreChat Cleanup & Exit

echo ====================================================
echo   Stopping LibreChat ^& Wiping Sensitive Data
echo ====================================================

:: [Step 1] Stop Docker containers and delete local DB volumes
if exist "LibreChat" (
    echo [1/4] Stopping Docker containers and removing volumes...
    cd LibreChat
    docker compose down -v
    cd ..

    :: [Step 2] Permanently delete LibreChat folder including .env (API keys)
    echo [2/4] Deleting LibreChat folder completely...
    rmdir /s /q LibreChat
) else (
    echo [INFO] LibreChat folder already removed.
)

:: [Step 3] Wipe current Windows clipboard and Win+V clipboard history
echo [3/4] Clearing Windows clipboard ^& history...
echo off | clip
powershell -NoProfile -Command "[Windows.ApplicationModel.DataTransfer.Clipboard, Windows, ContentType = WindowsRuntime]::ClearHistory()" >nul 2>nul

:: [Step 4] Clear API key variables from memory
echo [4/4] Clearing memory variables...
set ANTHROPIC_KEY=
set OPENAI_KEY=

echo ====================================================
echo   CLEANUP COMPLETE! Safe to leave the classroom PC.
echo ====================================================
pause
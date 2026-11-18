@echo off
cd /d "%~dp0"
title Codyssey LibreChat Launcher (Claude + OpenAI)

echo ====================================================
echo   Codyssey x LibreChat Auto Setup ^& Launcher
echo ====================================================

:: [Step 1] Check if Docker Desktop is installed
where docker >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Docker Desktop is not installed. Opening download page...
    start https://www.docker.com/products/docker-desktop/
    pause
    exit /b
)

:: [Step 2] Start Docker Desktop if stopped, and wait until engine is ready
docker info >nul 2>nul
if %errorlevel% neq 0 (
    echo [INFO] Docker Engine is stopped. Starting Docker Desktop...
    start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
)

:WAIT_DOCKER
docker info >nul 2>nul
if %errorlevel% neq 0 (
    echo [WAIT] Waiting for Docker Engine to be ready...
    timeout /t 3 /nobreak >nul
    goto WAIT_DOCKER
)
echo [OK] Docker Engine is running!

:: [Step 3] Clone LibreChat repository if not exists
if not exist "LibreChat" (
    echo [1/4] Cloning LibreChat repository...
    git clone https://github.com/danny-avila/LibreChat.git
)
cd LibreChat

:: [Step 4] Find an available port starting from 3080
set APP_PORT=3080
:CHECK_PORT
netstat -ano | findstr ":%APP_PORT% " | findstr "LISTENING" >nul
if %errorlevel% equ 0 (
    echo [INFO] Port %APP_PORT% is already in use. Trying next port...
    set /a APP_PORT+=1
    goto CHECK_PORT
)
echo [OK] Using available port: %APP_PORT%

:: [Step 5] Skip setup if .env already exists
if exist ".env" goto START_CONTAINERS

echo [2/4] Configuring security files...
copy .env.example .env >nul
copy docker-compose.override.yml.example docker-compose.override.yml >nul

set "ANTHROPIC_KEY="
set "OPENAI_KEY="

:: Prompt for API keys and immediately wipe Windows clipboard + Win+V history
echo.
set /p ANTHROPIC_KEY="Paste Codyssey ANTHROPIC API Key (or press Enter to skip): "
echo off | clip
powershell -NoProfile -Command "[Windows.ApplicationModel.DataTransfer.Clipboard, Windows, ContentType = WindowsRuntime]::ClearHistory()" >nul 2>nul

set /p OPENAI_KEY="Paste Codyssey OPENAI API Key (or press Enter to skip): "
echo off | clip
powershell -NoProfile -Command "[Windows.ApplicationModel.DataTransfer.Clipboard, Windows, ContentType = WindowsRuntime]::ClearHistory()" >nul 2>nul
echo [SECURITY] Clipboard history cleared.

:: Guard: Exit if both keys were skipped
if "%ANTHROPIC_KEY%"=="" if "%OPENAI_KEY%"=="" (
    echo [ERROR] Both API keys were skipped. At least one key is required.
    del /f /q .env >nul 2>nul
    pause
    exit /b
)

:: Write port, API keys, and endpoints to .env
echo.>> .env
echo PORT=%APP_PORT%>> .env
if not "%ANTHROPIC_KEY%"=="" echo CODYSSEY_ANTHROPIC_KEY=%ANTHROPIC_KEY%>> .env
if not "%ANTHROPIC_KEY%"=="" echo CODYSSEY_ANTHROPIC_URL=https://copa.codyssey.kr>> .env
if not "%OPENAI_KEY%"=="" echo CODYSSEY_OPENAI_KEY=%OPENAI_KEY%>> .env
if not "%OPENAI_KEY%"=="" echo CODYSSEY_OPENAI_URL=https://copa.codyssey.kr/v1>> .env

:: Generate librechat.yaml header
echo version: 1.3.18> librechat.yaml
echo cache: true>> librechat.yaml
echo endpoints:>> librechat.yaml
echo   custom:>> librechat.yaml

:: Register Claude endpoint only if ANTHROPIC_KEY was entered
if "%ANTHROPIC_KEY%"=="" goto SKIP_CLAUDE
echo     - name: 'Codyssey-Claude'>> librechat.yaml
echo       provider: 'anthropic'>> librechat.yaml
echo       apiKey: '${CODYSSEY_ANTHROPIC_KEY}'>> librechat.yaml
echo       baseURL: '${CODYSSEY_ANTHROPIC_URL}'>> librechat.yaml
echo       models:>> librechat.yaml
echo         default:>> librechat.yaml
echo           - 'claude-haiku-4'>> librechat.yaml
echo           - 'claude-sonnet-4'>> librechat.yaml
echo           - 'claude-opus-4-7'>> librechat.yaml
echo           - 'claude-opus-4-8'>> librechat.yaml
echo       titleConvo: false>> librechat.yaml
echo       modelDisplayLabel: 'Codyssey Claude'>> librechat.yaml
:SKIP_CLAUDE

:: Register OpenAI endpoint only if OPENAI_KEY was entered
if "%OPENAI_KEY%"=="" goto SKIP_OPENAI
echo     - name: 'Codyssey-OpenAI'>> librechat.yaml
echo       apiKey: '${CODYSSEY_OPENAI_KEY}'>> librechat.yaml
echo       baseURL: '${CODYSSEY_OPENAI_URL}'>> librechat.yaml
echo       models:>> librechat.yaml
echo         default:>> librechat.yaml
echo           - 'gpt-5-mini'>> librechat.yaml
echo           - 'gpt-5.4'>> librechat.yaml
echo       titleConvo: false>> librechat.yaml
echo       modelDisplayLabel: 'Codyssey OpenAI'>> librechat.yaml
:SKIP_OPENAI

:: Inject .env and mount librechat.yaml into the Docker container
echo services:> docker-compose.override.yml
echo   api:>> docker-compose.override.yml
echo     env_file:>> docker-compose.override.yml
echo       - .env>> docker-compose.override.yml
echo     volumes:>> docker-compose.override.yml
echo       - type: bind>> docker-compose.override.yml
echo         source: ./librechat.yaml>> docker-compose.override.yml
echo         target: /app/librechat.yaml>> docker-compose.override.yml

:START_CONTAINERS
:: [Step 6] Launch containers and open browser after 20s warmup
echo [3/4] Starting Docker containers...
docker compose up -d

echo [4/4] Waiting 20 seconds for web server startup...
timeout /t 20 /nobreak >nul
start http://localhost:%APP_PORT%

echo ====================================================
echo   DONE! Open http://localhost:%APP_PORT%
echo ====================================================
pause
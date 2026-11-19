@echo off
cd /d "%~dp0"
title Codyssey LibreChat Launcher (Claude + OpenAI)

echo ====================================================
echo   Codyssey x LibreChat Auto Setup ^& Launcher
echo ====================================================

:: [Step 1] Locate Docker Desktop executable across common paths and relative to docker CLI
set "DOCKER_EXE="
if exist "C:\Program Files\Docker\Docker\Docker Desktop.exe" set "DOCKER_EXE=C:\Program Files\Docker\Docker\Docker Desktop.exe"
if not defined DOCKER_EXE if exist "%LocalAppData%\Programs\Docker\Docker\Docker Desktop.exe" set "DOCKER_EXE=%LocalAppData%\Programs\Docker\Docker\Docker Desktop.exe"
if not defined DOCKER_EXE if exist "%LocalAppData%\Programs\DockerDesktop\Docker Desktop.exe" set "DOCKER_EXE=%LocalAppData%\Programs\DockerDesktop\Docker Desktop.exe"
if not defined DOCKER_EXE (
    for /f "delims=" %%i in ('where docker 2^>nul') do (
        if not defined DOCKER_EXE if exist "%%~dpi..\..\Docker Desktop.exe" set "DOCKER_EXE=%%~dpi..\..\Docker Desktop.exe"
    )
)

:: Guard: If Docker Desktop is not installed on this PC, open download page and exit
where docker >nul 2>nul
if %errorlevel% neq 0 if not defined DOCKER_EXE (
    echo [ERROR] Docker Desktop is not installed on this PC.
    echo         Opening the official download page. Please install it first!
    start https://www.docker.com/products/docker-desktop/
    pause
    exit /b
)

:: [Step 2] Start Docker Desktop if engine is stopped, and wait until ready
docker info >nul 2>nul
if %errorlevel% neq 0 (
    if defined DOCKER_EXE (
        echo [INFO] Docker Engine is stopped. Starting Docker Desktop...
        start "" "%DOCKER_EXE%"
    ) else (
        echo [ERROR] Docker CLI found, but Docker Desktop.exe could not be located.
        echo         Please start Docker manually or reinstall Docker Desktop.
        start https://www.docker.com/products/docker-desktop/
        pause
        exit /b
    )
)

:WAIT_DOCKER
docker info >nul 2>nul
if %errorlevel% neq 0 (
    echo [WAIT] Waiting for Docker Engine to be ready...
    timeout /t 3 /nobreak >nul
    goto WAIT_DOCKER
)
echo [OK] Docker Engine is running!

:: Check if Git is installed
where git >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Git is not installed on this PC.
    echo         Opening the official download page. Please install Git first!
    start https://git-scm.com/downloads/win
    pause
    exit /b
)

:: [Step 3] Clone LibreChat repository if not exists
if not exist "LibreChat" (
    echo [1/4] Cloning LibreChat repository...
    git clone https://github.com/danny-avila/LibreChat.git
)
cd LibreChat

:: [Step 4] Check if .env already exists AND contains a valid API key
if not exist ".env" goto FRESH_SETUP
findstr /r "^CODYSSEY_.*_KEY=." .env >nul 2>nul
if %errorlevel% neq 0 goto FRESH_SETUP

for /f "tokens=2 delims==" %%a in ('findstr "^PORT=" .env') do set APP_PORT=%%a
if not defined APP_PORT set APP_PORT=3080
goto START_CONTAINERS

:FRESH_SETUP
:: [Step 5] Find an available port starting from 3080
set APP_PORT=3080
:CHECK_PORT
netstat -ano | findstr ":%APP_PORT% " | findstr "LISTENING" >nul
if %errorlevel% equ 0 (
    echo [INFO] Port %APP_PORT% is already in use. Trying next port...
    set /a APP_PORT+=1
    goto CHECK_PORT
)
echo [OK] Using available port: %APP_PORT%

echo [2/4] Configuring security files...
copy .env.example .env >nul
copy docker-compose.override.yml.example docker-compose.override.yml >nul

set "ANTHROPIC_KEY="
set "OPENAI_KEY="

:: Prompt for API keys directly from CON and immediately wipe clipboard
echo.
set /p ANTHROPIC_KEY="Paste Codyssey ANTHROPIC API Key (or press Enter to skip): " < CON
if not "%ANTHROPIC_KEY%"=="" (
    echo off | clip
    powershell -NoProfile -Command "[Windows.ApplicationModel.DataTransfer.Clipboard, Windows, ContentType = WindowsRuntime]::ClearHistory()" >nul 2>nul
)

set /p OPENAI_KEY="Paste Codyssey OPENAI API Key (or press Enter to skip): " < CON
if not "%OPENAI_KEY%"=="" (
    echo off | clip
    powershell -NoProfile -Command "[Windows.ApplicationModel.DataTransfer.Clipboard, Windows, ContentType = WindowsRuntime]::ClearHistory()" >nul 2>nul
)
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

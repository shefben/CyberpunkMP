@echo off
setlocal enabledelayedexpansion

echo =====================================
echo Red4ext + CyberpunkMP Installation
echo =====================================

set "PROJECT_ROOT=%~dp0"
set "CYBERPUNK_PATH=F:\Hyperspin\Roms\Bens Games\Cyberpunk 2077"
set "BUILD_PATH=%PROJECT_ROOT%build\windows\x64\release"

echo Cyberpunk Path: %CYBERPUNK_PATH%
echo.

:: Check if Cyberpunk exists
if not exist "%CYBERPUNK_PATH%\bin\x64\Cyberpunk2077.exe" (
    echo ERROR: Cyberpunk 2077 not found at specified path!
    pause
    exit /b 1
)

echo =====================================
echo Step 1: Installing Red4ext Core
echo =====================================

:: Create red4ext directory structure
mkdir "%CYBERPUNK_PATH%\red4ext\plugins" 2>nul

:: Check if Red4ext is already installed
if not exist "%CYBERPUNK_PATH%\red4ext\RED4ext.dll" (
    echo [REQUIRED] Red4ext core not found!
    echo.
    echo You need to download Red4ext from:
    echo https://github.com/WopsS/RED4ext/releases
    echo.
    echo Please download RED4ext and extract these files to:
    echo "%CYBERPUNK_PATH%\red4ext\"
    echo.
    echo Required files:
    echo   - RED4ext.dll
    echo   - RED4ext.ini ^(optional^)
    echo.
    echo After installing Red4ext, run this script again.
    pause
    exit /b 1
) else (
    echo   ✓ RED4ext.dll found
)

echo =====================================
echo Step 2: Installing CyberpunkMP Plugin
echo =====================================

:: Remove existing symlink if it exists
if exist "%CYBERPUNK_PATH%\red4ext\plugins\zzzCyberpunkMP" (
    echo Removing existing zzzCyberpunkMP...
    rmdir "%CYBERPUNK_PATH%\red4ext\plugins\zzzCyberpunkMP" 2>nul
    del /f /q "%CYBERPUNK_PATH%\red4ext\plugins\zzzCyberpunkMP" 2>nul
)

:: Create the actual plugin directory
mkdir "%CYBERPUNK_PATH%\red4ext\plugins\zzzCyberpunkMP" 2>nul

:: Deploy CyberpunkMP Red4ext plugin
echo [1/2] Deploying CyberpunkMP Red4ext Plugin...

if exist "%BUILD_PATH%\CyberpunkMP.dll" (
    copy /Y "%BUILD_PATH%\CyberpunkMP.dll" "%CYBERPUNK_PATH%\red4ext\plugins\zzzCyberpunkMP\" >nul
    echo   ✓ CyberpunkMP.dll
) else (
    echo   ✗ CyberpunkMP.dll not found in build directory
    echo   Looking for alternative locations...

    :: Check other possible locations
    if exist "%PROJECT_ROOT%\build\windows\x64\debug\CyberpunkMP.dll" (
        copy /Y "%PROJECT_ROOT%\build\windows\x64\debug\CyberpunkMP.dll" "%CYBERPUNK_PATH%\red4ext\plugins\zzzCyberpunkMP\" >nul
        echo   ✓ CyberpunkMP.dll ^(from debug build^)
    ) else if exist "%PROJECT_ROOT%\CyberpunkMP.dll" (
        copy /Y "%PROJECT_ROOT%\CyberpunkMP.dll" "%CYBERPUNK_PATH%\red4ext\plugins\zzzCyberpunkMP\" >nul
        echo   ✓ CyberpunkMP.dll ^(from project root^)
    ) else (
        echo   ✗ CyberpunkMP.dll not found anywhere!
        echo   Please build the project first with: xmake build
    )
)

:: Create plugin config
echo [2/2] Creating plugin configuration...
echo {> "%CYBERPUNK_PATH%\red4ext\plugins\zzzCyberpunkMP\CyberpunkMP.json"
echo   "name": "CyberpunkMP",>> "%CYBERPUNK_PATH%\red4ext\plugins\zzzCyberpunkMP\CyberpunkMP.json"
echo   "version": "1.0.0",>> "%CYBERPUNK_PATH%\red4ext\plugins\zzzCyberpunkMP\CyberpunkMP.json"
echo   "author": "CyberpunkMP Team",>> "%CYBERPUNK_PATH%\red4ext\plugins\zzzCyberpunkMP\CyberpunkMP.json"
echo   "description": "Cyberpunk 2077 Multiplayer Mod">> "%CYBERPUNK_PATH%\red4ext\plugins\zzzCyberpunkMP\CyberpunkMP.json"
echo }>> "%CYBERPUNK_PATH%\red4ext\plugins\zzzCyberpunkMP\CyberpunkMP.json"
echo   ✓ CyberpunkMP.json

echo =====================================
echo Step 3: Installing Game Assets
echo =====================================

:: Deploy game archives
echo [1/3] Deploying game archives...
mkdir "%CYBERPUNK_PATH%\archive\pc\mod" 2>nul

if exist "%PROJECT_ROOT%\code\assets\Archives\packed\archive\pc\mod\CyberpunkMP.archive" (
    copy /Y "%PROJECT_ROOT%\code\assets\Archives\packed\archive\pc\mod\CyberpunkMP.archive" "%CYBERPUNK_PATH%\archive\pc\mod\" >nul
    echo   ✓ CyberpunkMP.archive
) else (
    echo   ! CyberpunkMP.archive not found - visuals may be affected
)

:: Deploy redscript files
echo [2/3] Deploying redscript files...
mkdir "%CYBERPUNK_PATH%\r6\scripts\CyberpunkMP" 2>nul
mkdir "%CYBERPUNK_PATH%\r6\scripts\CyberpunkMP\World" 2>nul
mkdir "%CYBERPUNK_PATH%\r6\scripts\CyberpunkMP\Ink" 2>nul

if exist "%PROJECT_ROOT%\code\assets\redscript\*.reds" (
    copy /Y "%PROJECT_ROOT%\code\assets\redscript\*.reds" "%CYBERPUNK_PATH%\r6\scripts\CyberpunkMP\" >nul 2>&1
    echo   ✓ Core redscript files
)

if exist "%PROJECT_ROOT%\code\assets\redscript\World" (
    xcopy /Y /S "%PROJECT_ROOT%\code\assets\redscript\World\*" "%CYBERPUNK_PATH%\r6\scripts\CyberpunkMP\World\" >nul 2>&1
    echo   ✓ World redscript files
)

if exist "%PROJECT_ROOT%\code\assets\redscript\Ink" (
    xcopy /Y /S "%PROJECT_ROOT%\code\assets\redscript\Ink\*" "%CYBERPUNK_PATH%\r6\scripts\CyberpunkMP\Ink\" >nul 2>&1
    echo   ✓ UI redscript files
)

:: Check for CET (optional)
echo [3/3] Checking for CET integration...
if exist "%CYBERPUNK_PATH%\bin\x64\plugins\cyber_engine_tweaks" (
    mkdir "%CYBERPUNK_PATH%\bin\x64\plugins\cyber_engine_tweaks\mods\CyberpunkMP" 2>nul
    if exist "%PROJECT_ROOT%\code\assets\CET" (
        xcopy /Y /S "%PROJECT_ROOT%\code\assets\CET\*" "%CYBERPUNK_PATH%\bin\x64\plugins\cyber_engine_tweaks\mods\CyberpunkMP\" >nul 2>&1
        echo   ✓ CET integration installed
    )
) else (
    echo   ! CET not installed (optional)
)

echo =====================================
echo Installation Verification
echo =====================================

set "ERRORS=0"

:: Check Red4ext
if exist "%CYBERPUNK_PATH%\red4ext\RED4ext.dll" (
    echo   ✓ Red4ext core installed
) else (
    echo   ✗ Red4ext core missing
    set /a ERRORS+=1
)

:: Check CyberpunkMP plugin
if exist "%CYBERPUNK_PATH%\red4ext\plugins\zzzCyberpunkMP\CyberpunkMP.dll" (
    echo   ✓ CyberpunkMP plugin installed
) else (
    echo   ✗ CyberpunkMP plugin missing
    set /a ERRORS+=1
)

:: Check redscript
if exist "%CYBERPUNK_PATH%\r6\scripts\CyberpunkMP\*.reds" (
    echo   ✓ Redscript files installed
) else (
    echo   ✗ Redscript files missing
    set /a ERRORS+=1
)

echo.
if %ERRORS% equ 0 (
    echo =====================================
    echo ✓ Installation Complete!
    echo =====================================
    echo.
    echo CyberpunkMP should now work properly!
    echo.
    echo WHAT TO DO NEXT:
    echo 1. Launch Cyberpunk 2077 normally or via CyberpunkMP launcher
    echo 2. Check the main menu for multiplayer options
    echo 3. Look for CyberpunkMP-related UI elements in game
    echo 4. Try connecting to a multiplayer server
    echo.
    echo TROUBLESHOOTING:
    echo - If no multiplayer options appear, check the game logs
    echo - Red4ext logs: %CYBERPUNK_PATH%\red4ext\logs\
    echo - Game logs: %CYBERPUNK_PATH%\r6\logs\
) else (
    echo =====================================
    echo ✗ Installation Incomplete
    echo =====================================
    echo.
    echo %ERRORS% critical error(s) found. Please fix these issues:
    echo.
    if not exist "%CYBERPUNK_PATH%\red4ext\RED4ext.dll" (
        echo • Download and install Red4ext from:
        echo   https://github.com/WopsS/RED4ext/releases
    )
    if not exist "%CYBERPUNK_PATH%\red4ext\plugins\zzzCyberpunkMP\CyberpunkMP.dll" (
        echo • Build CyberpunkMP.dll with: xmake build
    )
    if not exist "%CYBERPUNK_PATH%\r6\scripts\CyberpunkMP\*.reds" (
        echo • Ensure redscript files exist in code\assets\redscript\
    )
)

echo.
echo Press any key to exit...
pause >nul
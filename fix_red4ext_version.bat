@echo off
echo =====================================
echo RED4ext Version Compatibility Fix
echo =====================================

set "CYBERPUNK_PATH=F:\Hyperspin\Roms\Bens Games\Cyberpunk 2077"

echo Your Cyberpunk 2077 version: 1.60
echo Current RED4ext version: 1.29.1 (requires 2.31+)
echo.
echo INCOMPATIBILITY DETECTED!
echo.
echo You have 2 options:
echo.
echo ┌─ OPTION 1: Update Cyberpunk 2077 (Recommended) ────┐
echo │                                                     │
echo │ • Update your game to version 2.31 or newer        │
echo │ • Steam: Library → Cyberpunk 2077 → Update         │
echo │ • Epic: Library → Cyberpunk 2077 → Update          │
echo │ • GOG: Use GOG Galaxy to update                    │
echo │                                                     │
echo │ This is the BEST solution for compatibility        │
echo └─────────────────────────────────────────────────────┘
echo.
echo ┌─ OPTION 2: Downgrade RED4ext (Quick Fix) ──────────┐
echo │                                                     │
echo │ Download RED4ext v1.14.x or earlier from:          │
echo │ https://github.com/WopsS/RED4ext/releases          │
echo │                                                     │
echo │ Compatible versions for Cyberpunk 1.60:            │
echo │ • RED4ext v1.14.0                                  │
echo │ • RED4ext v1.13.x                                  │
echo │ • RED4ext v1.12.x                                  │
echo └─────────────────────────────────────────────────────┘
echo.
echo Current RED4ext location: %CYBERPUNK_PATH%\red4ext\RED4ext.dll
echo.

set /p choice="Do you want to backup current RED4ext? (y/n): "
if /i "%choice%"=="y" (
    echo Backing up current RED4ext.dll...
    copy "%CYBERPUNK_PATH%\red4ext\RED4ext.dll" "%CYBERPUNK_PATH%\red4ext\RED4ext.dll.backup" >nul
    echo   ✓ Backup created: RED4ext.dll.backup
)

echo.
echo =====================================
echo Manual Steps Required:
echo =====================================
echo.
echo 1. Visit: https://github.com/WopsS/RED4ext/releases
echo 2. Download RED4ext v1.14.0 (compatible with CP 1.60)
echo 3. Extract RED4ext.dll to: %CYBERPUNK_PATH%\red4ext\
echo 4. Overwrite the existing file
echo 5. Try launching CyberpunkMP again
echo.
echo OR
echo.
echo Update Cyberpunk 2077 to version 2.31+ (recommended)
echo.
pause
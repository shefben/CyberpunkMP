@echo off
echo Fixing CyberpunkMP Permissions...

set "CYBERPUNK_PATH=F:\Hyperspin\Roms\Bens Games\Cyberpunk 2077"

echo [1/4] Taking ownership of Cyberpunk directory...
takeown /f "%CYBERPUNK_PATH%" /r /d y >nul 2>&1

echo [2/4] Granting full control to current user...
icacls "%CYBERPUNK_PATH%" /grant %USERNAME%:F /t /c /q >nul 2>&1

echo [3/4] Removing read-only attributes...
attrib -r "%CYBERPUNK_PATH%\*" /s /d >nul 2>&1

echo [4/4] Cleaning up problematic symlink...
if exist "%CYBERPUNK_PATH%\red4ext\plugins\zzzCyberpunkMP" (
    rmdir /s /q "%CYBERPUNK_PATH%\red4ext\plugins\zzzCyberpunkMP" >nul 2>&1
    echo   ✓ Removed existing zzzCyberpunkMP folder
)

echo.
echo ✓ Permissions fixed! You can now run the launcher normally.
echo.
pause
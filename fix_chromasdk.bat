@echo off
echo Fixing ChromaSDK Plugin Error...

set "CYBERPUNK_PATH=F:\Hyperspin\Roms\Bens Games\Cyberpunk 2077"

:: Rename the ChromaSDK plugin to disable it
if exist "%CYBERPUNK_PATH%\bin\x64\plugins\ChromaSDKPlugin.dll" (
    ren "%CYBERPUNK_PATH%\bin\x64\plugins\ChromaSDKPlugin.dll" "ChromaSDKPlugin.dll.disabled"
    echo   ✓ ChromaSDK plugin disabled
) else (
    echo   ! ChromaSDK plugin not found (error might be from elsewhere)
)

:: Create a dummy ChromaSDK to prevent the error
echo Creating dummy ChromaSDK file...
echo. > "%CYBERPUNK_PATH%\bin\x64\plugins\ChromaSDKPlugin.txt"
echo   ✓ Dummy file created to prevent missing file error

echo.
echo ChromaSDK error should be resolved.
pause
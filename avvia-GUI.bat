@echo off
REM Launcher per Fabry-Frame-Extractor-GUI.ps1
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Fabry-Frame-Extractor-GUI.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Errore durante l'esecuzione.
    pause
)
endlocal

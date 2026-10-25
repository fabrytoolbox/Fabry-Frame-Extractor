@echo off
REM Launcher per Fabry-Frame-Extractor-CLI.ps1
REM Uso: avvia-CLI.bat -ConfigFilePath "config.csv" -RootOutputPath "output"
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Fabry-Frame-Extractor-CLI.ps1" %*
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Errore durante l'esecuzione.
    pause
)
endlocal

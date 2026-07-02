@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "SETUP_SCRIPT=%SCRIPT_DIR%Configure-And-Launch-Antreva-Remote-Pilot.ps1"

if not exist "%SETUP_SCRIPT%" (
  echo Missing setup script:
  echo %SETUP_SCRIPT%
  echo.
  pause
  exit /b 1
)

echo Starting Antreva Remote Pilot setup...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SETUP_SCRIPT%"

if errorlevel 1 (
  echo.
  echo Setup did not finish successfully.
  echo Please send Steve a screenshot of this window.
  echo.
  pause
  exit /b 1
)

echo.
echo Antreva Remote Pilot setup launched.
endlocal

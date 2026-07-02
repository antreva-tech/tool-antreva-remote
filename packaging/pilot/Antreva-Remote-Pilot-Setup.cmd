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

echo Starting Antreva Desk 0.1.0 setup...
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "if ($PSVersionTable.PSVersion.Major -lt 3) { Write-Host 'PowerShell 5.1 or newer is required on Windows 7. PowerShell 3 or newer is required on Windows 8 through Windows 11.'; exit 10 }"

if errorlevel 1 (
  echo.
  echo PowerShell compatibility check failed.
  echo PowerShell 5.1 or newer is required on Windows 7.
  echo Install Windows Management Framework 5.1, then run this setup again.
  echo.
  pause
  exit /b 1
)

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
echo Antreva Desk 0.1.0 setup launched.
endlocal

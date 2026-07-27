@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "ANTREVA_VERSION=1.0.3"
set "RUSTDESK_VERSION=1.4.8"
set "SCRIPT_DIR=%~dp0"
set "SERVER_HOST=104.184.67.190"
set "SERVER_KEY=YS9ei5TCWktK9TjR5ZkE1sagedm4XmZWRX+kWfkisEg="
set "RUSTDESK_CONFIG_NAME=rustdesk-host=%SERVER_HOST%,key=%SERVER_KEY%,relay=%SERVER_HOST%.exe"
set "LOG_ENABLED=0"

if /I "%~1"=="--verify-bundle" goto verify_bundle
if /I "%~1"=="--elevated" goto elevated

:request_elevation
fltmc.exe >nul 2>&1
if not errorlevel 1 goto elevated

echo Antreva Desk setup requires administrator permission.
echo Requesting Windows administrator approval...
set "ELEVATE_SCRIPT=%TEMP%\AntrevaDesk-Elevate-%RANDOM%-%RANDOM%.vbs"
call :WriteElevationScript
wscript.exe "%ELEVATE_SCRIPT%" "%~f0" "%SCRIPT_DIR%" "%ComSpec%"
set "ELEVATE_EXIT=%ERRORLEVEL%"
del /q "%ELEVATE_SCRIPT%" >nul 2>&1
if not "%ELEVATE_EXIT%"=="0" (
  echo.
  echo Windows administrator approval was not completed.
  pause
  exit /b 1
)
exit /b 0

:elevated
fltmc.exe >nul 2>&1
if errorlevel 1 (
  echo Antreva Desk setup must be run as Administrator.
  pause
  exit /b 1
)

set "LOG_DIR=%ProgramData%\AntrevaDesk\Logs"
set "LOG_PATH=%LOG_DIR%\AntrevaDesk-Setup.log"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1
> "%LOG_PATH%" echo Antreva Desk %ANTREVA_VERSION% Command Prompt setup
set "LOG_ENABLED=1"

call :RunSetup
set "SETUP_EXIT=%ERRORLEVEL%"
echo.
if not "%SETUP_EXIT%"=="0" (
  call :Log "Setup did not finish successfully."
  echo Log file: %LOG_PATH%
  echo.
  pause
  exit /b %SETUP_EXIT%
)

call :Log "Antreva Desk %ANTREVA_VERSION% setup completed successfully."
echo Log file: %LOG_PATH%
echo.
pause
exit /b 0

:verify_bundle
echo Verifying Antreva Desk %ANTREVA_VERSION% Command Prompt bundle...
call :SelectArchitecture
if errorlevel 1 exit /b 1
call :VerifyPayloadHash
if errorlevel 1 exit /b 1
set "ELEVATE_SCRIPT=%TEMP%\AntrevaDesk-Elevate-Verify-%RANDOM%-%RANDOM%.vbs"
call :WriteElevationScript
cscript.exe //nologo "%ELEVATE_SCRIPT%"
set "ELEVATION_VERIFY_EXIT=%ERRORLEVEL%"
del /q "%ELEVATE_SCRIPT%" >nul 2>&1
if not "%ELEVATION_VERIFY_EXIT%"=="0" (
  echo Command Prompt elevation helper verification failed.
  exit /b 1
)
echo Command Prompt bundle verification passed for %SELECTED_ARCH%.
exit /b 0

:RunSetup
call :Log "Starting Antreva Desk %ANTREVA_VERSION% Command Prompt setup."
call :SelectArchitecture
if errorlevel 1 exit /b 1
call :PreflightWindows
if errorlevel 1 exit /b 1
call :VerifyPayloadHash
if errorlevel 1 exit /b 1
call :PromptForPassword
if errorlevel 1 exit /b 1
call :InstallRustDesk
if errorlevel 1 exit /b 1
call :ConfigureRustDesk
if errorlevel 1 exit /b 1
call :SetPermanentPassword
if errorlevel 1 exit /b 1
call :VerifyPersistedState
if errorlevel 1 exit /b 1
call :CreateAntrevaShortcuts
if errorlevel 1 exit /b 1
call :Log "Launching Antreva Desk."
start "" "%INSTALLED_EXE%"
exit /b 0

:SelectArchitecture
set "SELECTED_ARCH="
if /I "%PROCESSOR_ARCHITECTURE%"=="ARM64" (
  call :Fail "Windows ARM64 is not supported by this release."
  exit /b 1
)
if /I "%PROCESSOR_ARCHITEW6432%"=="ARM64" (
  call :Fail "Windows ARM64 is not supported by this release."
  exit /b 1
)
if /I "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "SELECTED_ARCH=x64"
if /I "%PROCESSOR_ARCHITEW6432%"=="AMD64" set "SELECTED_ARCH=x64"
if /I "%PROCESSOR_ARCHITECTURE%"=="x86" if not defined SELECTED_ARCH set "SELECTED_ARCH=x86"
if not defined SELECTED_ARCH (
  call :Fail "Could not determine whether Windows is 32-bit or 64-bit."
  exit /b 1
)

if "%SELECTED_ARCH%"=="x64" (
  set "PAYLOAD_FILE=rustdesk-1.4.8-x86_64.exe"
  set "PAYLOAD_HASH=F0053229FA2A2459C8B86F326C3E7423018A72F010F9758DC21BE171B112D1B2"
) else (
  set "PAYLOAD_FILE=rustdesk-1.4.8-x86-sciter.exe"
  set "PAYLOAD_HASH=10A14578ED3ADBAB66BFE5C8DAA0D49D07E002D48F69F303966EA349F58DFEA7"
)
set "PAYLOAD_PATH=%SCRIPT_DIR%payloads\%SELECTED_ARCH%\%PAYLOAD_FILE%"
if not exist "%PAYLOAD_PATH%" (
  call :Fail "The required %SELECTED_ARCH% RustDesk payload is missing."
  exit /b 1
)
call :Log "Selected the %SELECTED_ARCH% RustDesk payload."
exit /b 0

:PreflightWindows
set "WINDOWS_BUILD="
set "WINDOWS_PRODUCT="
for /f "tokens=2,*" %%A in ('reg.exe query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber 2^>nul ^| find.exe /I "CurrentBuildNumber"') do set "WINDOWS_BUILD=%%B"
for /f "tokens=2,*" %%A in ('reg.exe query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v ProductName 2^>nul ^| find.exe /I "ProductName"') do set "WINDOWS_PRODUCT=%%B"

if not defined WINDOWS_BUILD (
  call :Fail "Could not determine the Windows build number."
  exit /b 1
)
if not defined WINDOWS_PRODUCT set "WINDOWS_PRODUCT=Windows client"
echo(%WINDOWS_PRODUCT%| find.exe /I "Server" >nul
if not errorlevel 1 (
  call :Fail "Windows Server editions are not supported."
  exit /b 1
)

set /a WINDOWS_BUILD_NUMBER=%WINDOWS_BUILD% >nul 2>&1
if errorlevel 1 (
  call :Fail "Windows returned an invalid build number."
  exit /b 1
)
if %WINDOWS_BUILD_NUMBER% LSS 7601 (
  call :Fail "Windows 7 support requires Service Pack 1."
  exit /b 1
)
if %WINDOWS_BUILD_NUMBER% GTR 7601 if %WINDOWS_BUILD_NUMBER% LSS 9200 (
  call :Fail "This Windows client version is not supported."
  exit /b 1
)
if "%WINDOWS_BUILD_NUMBER%"=="7601" (
  call :CheckWindows7Hotfix "KB4490628"
  if errorlevel 1 exit /b 1
  call :CheckWindows7Hotfix "KB4474419"
  if errorlevel 1 exit /b 1
)
call :Log "Windows preflight passed: %WINDOWS_PRODUCT%, build %WINDOWS_BUILD%, %SELECTED_ARCH%."
exit /b 0

:CheckWindows7Hotfix
set "WMIC_PATH=%SystemRoot%\System32\wbem\wmic.exe"
if not exist "%WMIC_PATH%" (
  call :Fail "Windows 7 prerequisite detection requires WMIC."
  exit /b 1
)
"%WMIC_PATH%" qfe where "HotFixID='%~1'" get HotFixID /value 2>nul | find.exe /I "%~1" >nul
if errorlevel 1 (
  call :Fail "Windows 7 is missing required SHA-2 update %~1."
  exit /b 1
)
exit /b 0

:VerifyPayloadHash
where.exe certutil.exe >nul 2>&1
if errorlevel 1 (
  call :Fail "Windows certutil.exe is required to verify the RustDesk payload."
  exit /b 1
)
set "HASH_OUTPUT=%TEMP%\AntrevaDesk-Hash-%RANDOM%-%RANDOM%.txt"
certutil.exe -hashfile "%PAYLOAD_PATH%" SHA256 > "%HASH_OUTPUT%" 2>&1
if errorlevel 1 (
  type "%HASH_OUTPUT%"
  if "%LOG_ENABLED%"=="1" type "%HASH_OUTPUT%" >> "%LOG_PATH%"
  del /q "%HASH_OUTPUT%" >nul 2>&1
  call :Fail "Windows could not calculate the RustDesk payload hash."
  exit /b 1
)
find.exe /I "%PAYLOAD_HASH%" "%HASH_OUTPUT%" >nul
if errorlevel 1 (
  type "%HASH_OUTPUT%"
  if "%LOG_ENABLED%"=="1" type "%HASH_OUTPUT%" >> "%LOG_PATH%"
  del /q "%HASH_OUTPUT%" >nul 2>&1
  call :Fail "The RustDesk payload hash does not match the pinned release."
  exit /b 1
)
del /q "%HASH_OUTPUT%" >nul 2>&1
call :Log "Verified the exact pinned SHA-256 for %PAYLOAD_FILE%."
exit /b 0

:PromptForPassword
echo.
echo The permanent support password is visible while you type.
echo Use only letters, numbers, @, period, or underscore.
set "SUPPORT_PASSWORD="
set "SUPPORT_PASSWORD_CONFIRM="
set /p "SUPPORT_PASSWORD=Permanent support password: "
call :ValidatePassword SUPPORT_PASSWORD
if errorlevel 1 (
  call :Fail "The password must be non-empty and use only letters, numbers, @, period, or underscore."
  exit /b 1
)
set /p "SUPPORT_PASSWORD_CONFIRM=Confirm permanent support password: "
call :ValidatePassword SUPPORT_PASSWORD_CONFIRM
if errorlevel 1 (
  set "SUPPORT_PASSWORD="
  call :Fail "The confirmation password contains unsupported characters."
  exit /b 1
)
if not "%SUPPORT_PASSWORD%"=="%SUPPORT_PASSWORD_CONFIRM%" (
  set "SUPPORT_PASSWORD="
  set "SUPPORT_PASSWORD_CONFIRM="
  call :Fail "Permanent support passwords did not match."
  exit /b 1
)
set "SUPPORT_PASSWORD_CONFIRM="
exit /b 0

:ValidatePassword
setlocal EnableDelayedExpansion
set "PASSWORD_VALUE=!%~1!"
if not defined PASSWORD_VALUE endlocal & exit /b 1
set "PASSWORD_CHECK=%TEMP%\AntrevaDesk-Password-%RANDOM%-%RANDOM%.txt"
> "!PASSWORD_CHECK!" echo(!PASSWORD_VALUE!
findstr.exe /R /X "[A-Za-z0-9@._][A-Za-z0-9@._]*" "!PASSWORD_CHECK!" >nul
set "PASSWORD_VALID=!ERRORLEVEL!"
del /q "!PASSWORD_CHECK!" >nul 2>&1
endlocal & exit /b %PASSWORD_VALID%

:InstallRustDesk
call :Log "Stopping existing RustDesk processes."
taskkill.exe /IM rustdesk.exe /F >nul 2>&1
set "INSTALL_OUTPUT=%TEMP%\AntrevaDesk-Install-%RANDOM%-%RANDOM%.txt"
del /q "%INSTALL_OUTPUT%" >nul 2>&1
call :Log "Installing the RustDesk managed service."
start "" /b "%PAYLOAD_PATH%" --silent-install > "%INSTALL_OUTPUT%" 2>&1
set /a INSTALL_WAIT_COUNT=0

:wait_for_install
call :FindInstalledRustDesk
if defined INSTALLED_EXE goto install_found
set /a INSTALL_WAIT_COUNT+=1
if %INSTALL_WAIT_COUNT% GEQ 60 (
  if exist "%INSTALL_OUTPUT%" (
    type "%INSTALL_OUTPUT%"
    if "%LOG_ENABLED%"=="1" type "%INSTALL_OUTPUT%" >> "%LOG_PATH%"
  )
  call :Fail "RustDesk installation did not create the installed executable within 120 seconds."
  exit /b 1
)
timeout.exe /t 2 /nobreak >nul
goto wait_for_install

:install_found
call :Log "Installed RustDesk executable found. Waiting for installer finalization."
timeout.exe /t 20 /nobreak >nul
taskkill.exe /IM "%PAYLOAD_FILE%" /F >nul 2>&1
if exist "%INSTALL_OUTPUT%" (
  if "%LOG_ENABLED%"=="1" type "%INSTALL_OUTPUT%" >> "%LOG_PATH%"
  del /q "%INSTALL_OUTPUT%" >nul 2>&1
)
call :Log "RustDesk service installation completed: %INSTALLED_EXE%"
exit /b 0

:FindInstalledRustDesk
set "INSTALLED_EXE="
if exist "%ProgramFiles%\RustDesk\RustDesk.exe" set "INSTALLED_EXE=%ProgramFiles%\RustDesk\RustDesk.exe"
if not defined INSTALLED_EXE if exist "%ProgramFiles%\RustDesk\rustdesk.exe" set "INSTALLED_EXE=%ProgramFiles%\RustDesk\rustdesk.exe"
if not defined INSTALLED_EXE if exist "%ProgramFiles(x86)%\RustDesk\RustDesk.exe" set "INSTALLED_EXE=%ProgramFiles(x86)%\RustDesk\RustDesk.exe"
if not defined INSTALLED_EXE if exist "%ProgramFiles(x86)%\RustDesk\rustdesk.exe" set "INSTALLED_EXE=%ProgramFiles(x86)%\RustDesk\rustdesk.exe"
exit /b 0

:ConfigureRustDesk
call :Log "Importing the Antreva server configuration."
call :RunRustDesk --config "%RUSTDESK_CONFIG_NAME%"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "custom-rendezvous-server" "%SERVER_HOST%"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "relay-server" "%SERVER_HOST%"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "key" "%SERVER_KEY%"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "access-mode" "password"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "approve-mode" "password"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "verification-method" "use-permanent-password"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "enable-keyboard" "Y"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "enable-clipboard" "Y"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "enable-file-transfer" "Y"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "enable-file-copy-paste" "Y"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "one-way-file-transfer" "N"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "file-transfer-max-files" "200"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "enable-terminal" "N"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "enable-tunnel" "N"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "enable-remote-printer" "N"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "enable-remote-restart" "N"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "enable-record-session" "N"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "enable-block-input" "N"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "enable-privacy-mode" "N"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "allow-remote-config-modification" "N"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "allow-auto-update" "N"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "hide-tray" "N"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "hide-server-settings" "Y"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "hide-proxy-settings" "Y"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "hide-security-settings" "N"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "hide-stop-service" "N"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "disable-change-permanent-password" "N"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "disable-change-id" "Y"
if errorlevel 1 exit /b 1
call :SetRustDeskOption "disable-unlock-pin" "Y"
if errorlevel 1 exit /b 1
exit /b 0

:SetRustDeskOption
call :Log "Applying RustDesk option: %~1"
call :RunRustDesk --option "%~1" "%~2"
exit /b %ERRORLEVEL%

:RunRustDesk
set "RUSTDESK_OUTPUT=%TEMP%\AntrevaDesk-RustDesk-%RANDOM%-%RANDOM%.txt"
"%INSTALLED_EXE%" %* > "%RUSTDESK_OUTPUT%" 2>&1
set "RUSTDESK_EXIT=%ERRORLEVEL%"
if "%LOG_ENABLED%"=="1" type "%RUSTDESK_OUTPUT%" >> "%LOG_PATH%"
findstr.exe /I /C:"Installation and administrative privileges required" /C:"Settings are disabled" /C:"Changing permanent password is disabled" /C:"rejected" /C:"failed" /C:"error" "%RUSTDESK_OUTPUT%" >nul
if not errorlevel 1 set "RUSTDESK_EXIT=1"
if not "%RUSTDESK_EXIT%"=="0" type "%RUSTDESK_OUTPUT%"
del /q "%RUSTDESK_OUTPUT%" >nul 2>&1
if not "%RUSTDESK_EXIT%"=="0" (
  call :Fail "RustDesk rejected a managed setup command."
  exit /b 1
)
exit /b 0

:SetPermanentPassword
call :Log "Setting the permanent support password."
call :RunRustDesk --password "%SUPPORT_PASSWORD%"
set "PASSWORD_EXIT=%ERRORLEVEL%"
set "SUPPORT_PASSWORD="
if not "%PASSWORD_EXIT%"=="0" exit /b 1
exit /b 0

:VerifyPersistedState
call :Log "Verifying the Antreva server configuration through RustDesk."
timeout.exe /t 3 /nobreak >nul
call :VerifyRustDeskOption "custom-rendezvous-server" "%SERVER_HOST%" "required"
if errorlevel 1 exit /b 1
call :VerifyRustDeskOption "relay-server" "%SERVER_HOST%" "allow-blank"
if errorlevel 1 exit /b 1
call :VerifyRustDeskOption "key" "%SERVER_KEY%" "required"
if errorlevel 1 exit /b 1
call :FindRustDeskConfig
if errorlevel 1 exit /b 1
call :VerifyConfigLine "custom-rendezvous-server" "%SERVER_HOST%"
if errorlevel 1 exit /b 1
call :VerifyConfigLine "key" "%SERVER_KEY%"
if errorlevel 1 exit /b 1
call :FindRustDeskMainConfig
if errorlevel 1 exit /b 1
findstr.exe /I /R /C:"^[ ]*password[ ]*=" "%RUSTDESK_MAIN_CONFIG%" | findstr.exe /C:"01" >nul
if errorlevel 1 (
  call :Fail "RustDesk permanent password storage was not verified in RustDesk.toml."
  exit /b 1
)
findstr.exe /I /R /C:"^[ ]*salt[ ]*=" "%RUSTDESK_MAIN_CONFIG%" >nul
if errorlevel 1 (
  call :Fail "RustDesk permanent password salt was not verified in RustDesk.toml."
  exit /b 1
)
call :Log "Verified Antreva server settings in RustDesk2.toml and permanent password state in RustDesk.toml."
exit /b 0

:VerifyRustDeskOption
set "OPTION_OUTPUT=%TEMP%\AntrevaDesk-Option-%RANDOM%-%RANDOM%.txt"
"%INSTALLED_EXE%" --option "%~1" > "%OPTION_OUTPUT%" 2>&1
set "OPTION_EXIT=%ERRORLEVEL%"
set "ACTUAL_OPTION="
set /p "ACTUAL_OPTION="<"%OPTION_OUTPUT%"
if "%LOG_ENABLED%"=="1" type "%OPTION_OUTPUT%" >> "%LOG_PATH%"
del /q "%OPTION_OUTPUT%" >nul 2>&1
if not "%OPTION_EXIT%"=="0" (
  call :Fail "RustDesk could not read back option %~1."
  exit /b 1
)
if "%~3"=="allow-blank" if not defined ACTUAL_OPTION exit /b 0
if not "%ACTUAL_OPTION%"=="%~2" (
  call :Fail "RustDesk option %~1 did not persist with the required value."
  exit /b 1
)
exit /b 0

:FindRustDeskConfig
set "RUSTDESK_CONFIG="
for %%P in (
  "%APPDATA%\RustDesk\config\RustDesk2.toml"
  "%ProgramData%\RustDesk\config\RustDesk2.toml"
  "%LOCALAPPDATA%\RustDesk\config\RustDesk2.toml"
) do if not defined RUSTDESK_CONFIG if exist "%%~P" set "RUSTDESK_CONFIG=%%~P"
if not defined RUSTDESK_CONFIG (
  call :Fail "RustDesk2.toml was not found after configuration."
  exit /b 1
)
exit /b 0

:VerifyConfigLine
findstr.exe /I /C:"%~1" "%RUSTDESK_CONFIG%" | findstr.exe /L /C:"%~2" >nul
if errorlevel 1 (
  call :Fail "RustDesk2.toml does not contain the required %~1 value."
  exit /b 1
)
exit /b 0

:FindRustDeskMainConfig
set "RUSTDESK_MAIN_CONFIG="
for %%P in (
  "%APPDATA%\RustDesk\config\RustDesk.toml"
  "%ProgramData%\RustDesk\config\RustDesk.toml"
  "%LOCALAPPDATA%\RustDesk\config\RustDesk.toml"
) do if not defined RUSTDESK_MAIN_CONFIG if exist "%%~P" set "RUSTDESK_MAIN_CONFIG=%%~P"
if not defined RUSTDESK_MAIN_CONFIG (
  call :Fail "RustDesk.toml was not found after setting the permanent password."
  exit /b 1
)
exit /b 0

:CreateAntrevaShortcuts
set "ANTREVA_DIR=%LOCALAPPDATA%\AntrevaDesk"
set "ANTREVA_LAUNCHER=%ANTREVA_DIR%\Launch Antreva Desk.cmd"
set "START_MENU_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Antreva"
if not exist "%ANTREVA_DIR%" mkdir "%ANTREVA_DIR%" >nul 2>&1
if not exist "%START_MENU_DIR%" mkdir "%START_MENU_DIR%" >nul 2>&1
> "%ANTREVA_LAUNCHER%" echo @echo off
>> "%ANTREVA_LAUNCHER%" echo start "" "%INSTALLED_EXE%"
copy /Y "%ANTREVA_LAUNCHER%" "%USERPROFILE%\Desktop\Antreva Desk.cmd" >nul
if errorlevel 1 (
  call :Fail "Could not create the Antreva Desk desktop launcher."
  exit /b 1
)
copy /Y "%ANTREVA_LAUNCHER%" "%START_MENU_DIR%\Antreva Desk.cmd" >nul
if errorlevel 1 (
  call :Fail "Could not create the Antreva Desk Start Menu launcher."
  exit /b 1
)
call :Log "Created visible Antreva Desk launchers."
exit /b 0

:WriteElevationScript
> "%ELEVATE_SCRIPT%" echo If WScript.Arguments.Count = 0 Then WScript.Quit 0
>> "%ELEVATE_SCRIPT%" echo Set UAC = CreateObject^("Shell.Application"^)
>> "%ELEVATE_SCRIPT%" echo UAC.ShellExecute WScript.Arguments^(2^), "/d /c call """ ^& WScript.Arguments^(0^) ^& """ --elevated", WScript.Arguments^(1^), "runas", 1
exit /b 0

:Log
echo(%~1
if "%LOG_ENABLED%"=="1" >> "%LOG_PATH%" echo [%DATE% %TIME%] %~1
exit /b 0

:Fail
call :Log "ERROR: %~1"
exit /b 1

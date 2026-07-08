Unicode true

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "nsDialogs.nsh"
!include "x64.nsh"
!include "WinMessages.nsh"

!ifndef OUTFILE
  !define OUTFILE "AntrevaDesk-Setup-0.1.0.exe"
!endif

Name "AntrevaDesk"
OutFile "${OUTFILE}"
RequestExecutionLevel admin
InstallButtonText "Install"
BrandingText "AntrevaDesk"
Icon "assets\antrevadesk.ico"

!define MUI_ICON "assets\antrevadesk.ico"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "assets\banner.bmp"
!define MUI_HEADERIMAGE_RIGHT
!define MUI_WELCOMEFINISHPAGE_BITMAP "assets\dialog.bmp"
!define MUI_WELCOMEPAGE_TITLE "AntrevaDesk Setup"
!define MUI_WELCOMEPAGE_TEXT "This installer will set up AntrevaDesk managed support on this computer. Administrator approval and a permanent support password are required during setup."
!define MUI_FINISHPAGE_TITLE "AntrevaDesk setup finished"
!define MUI_FINISHPAGE_TEXT "AntrevaDesk setup has finished. If setup reported an error, review the installer details and AntrevaDesk setup log."

Var ARCH_X64
Var ARCH_X86
Var SelectedArchitecture
Var PortableExe
Var SetupScript
Var PASSWORD_ONE
Var PASSWORD_TWO
Var PasswordOneInput
Var PasswordTwoInput

!insertmacro MUI_PAGE_WELCOME
Page custom AntrevaDeskArchitecturePage AntrevaDeskArchitecturePageLeave
Page custom AntrevaDeskPasswordPage AntrevaDeskPasswordPageLeave
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_LANGUAGE "English"

Function .onInit
  StrCpy $SelectedArchitecture "x86"
  ${If} ${RunningX64}
    StrCpy $SelectedArchitecture "x64"
  ${EndIf}
FunctionEnd

; AntrevaDesk ArchitecturePage
Function AntrevaDeskArchitecturePage
  nsDialogs::Create 1018
  Pop $0
  ${If} $0 == error
    Abort
  ${EndIf}

  ${NSD_CreateLabel} 0 0 100% 26u "Choose which AntrevaDesk installer payload to use for this computer."
  Pop $0

  ${NSD_CreateRadioButton} 10u 38u 90% 14u "64-bit (recommended for 64-bit Windows)"
  Pop $ARCH_X64
  ${NSD_CreateRadioButton} 10u 58u 90% 14u "32-bit (for 32-bit Windows)"
  Pop $ARCH_X86

  ${If} ${RunningX64}
    ${NSD_Check} $ARCH_X64
  ${Else}
    ${NSD_Check} $ARCH_X86
    EnableWindow $ARCH_X64 0
  ${EndIf}

  nsDialogs::Show
FunctionEnd

Function AntrevaDeskArchitecturePageLeave
  ${NSD_GetState} $ARCH_X64 $0
  ${If} $0 == ${BST_CHECKED}
    StrCpy $SelectedArchitecture "x64"
  ${Else}
    StrCpy $SelectedArchitecture "x86"
  ${EndIf}
FunctionEnd

; AntrevaDesk PasswordPage
Function AntrevaDeskPasswordPage
  nsDialogs::Create 1018
  Pop $0
  ${If} $0 == error
    Abort
  ${EndIf}

  ${NSD_CreateLabel} 0 0 100% 24u "Set the permanent support password for this AntrevaDesk client."
  Pop $0
  ${NSD_CreateLabel} 0 34u 100% 10u "Permanent support password"
  Pop $0
  ${NSD_CreatePassword} 0 47u 100% 12u ""
  Pop $PasswordOneInput

  ${NSD_CreateLabel} 0 70u 100% 10u "Confirm permanent support password"
  Pop $0
  ${NSD_CreatePassword} 0 83u 100% 12u ""
  Pop $PasswordTwoInput

  ${NSD_CreateLabel} 0 110u 100% 24u "This password is required for later authorized support sessions. Keep it with the customer's support record."
  Pop $0

  nsDialogs::Show
FunctionEnd

Function AntrevaDeskPasswordPageLeave
  ${NSD_GetText} $PasswordOneInput $PASSWORD_ONE
  ${NSD_GetText} $PasswordTwoInput $PASSWORD_TWO

  ${If} $PASSWORD_ONE == ""
    MessageBox MB_ICONEXCLAMATION "Permanent support password cannot be empty."
    Abort
  ${EndIf}
  ${If} $PASSWORD_ONE != $PASSWORD_TWO
    MessageBox MB_ICONEXCLAMATION "Permanent support passwords did not match."
    Abort
  ${EndIf}
FunctionEnd

Section "Install AntrevaDesk"
  SetDetailsPrint both
  DetailPrint "Preparing AntrevaDesk $SelectedArchitecture setup..."

  InitPluginsDir
  SetOutPath "$PLUGINSDIR"
  File /r "staging\setup"
  File /r "staging\payloads"

  StrCpy $SetupScript "$PLUGINSDIR\setup\Configure-And-Launch-Antreva-Remote-Pilot.ps1"
  ${If} $SelectedArchitecture == "x64"
    StrCpy $PortableExe "$PLUGINSDIR\payloads\x64\rustdesk-1.4.8-x86_64.exe"
  ${Else}
    StrCpy $PortableExe "$PLUGINSDIR\payloads\x86\rustdesk-1.4.8-x86-sciter.exe"
  ${EndIf}

  DetailPrint "Running AntrevaDesk managed setup..."
  System::Call 'Kernel32::SetEnvironmentVariable(t "ANTREVA_DESK_PASSWORD", t "$PASSWORD_ONE") i.r1'
  nsExec::ExecToLog '"powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "$SetupScript" -Architecture "$SelectedArchitecture" -PortableExe "$PortableExe" -PasswordEnvironmentVariable "ANTREVA_DESK_PASSWORD"'
  Pop $0
  System::Call 'Kernel32::SetEnvironmentVariable(t "ANTREVA_DESK_PASSWORD", t "") i.r1'
  StrCpy $PASSWORD_ONE ""
  StrCpy $PASSWORD_TWO ""
  ${If} $0 != 0
    SetErrors
    MessageBox MB_ICONSTOP "AntrevaDesk setup did not finish successfully. Exit code: $0.$\r$\n$\r$\nPlease review the installer details and AntrevaDesk setup log."
  ${EndIf}
SectionEnd

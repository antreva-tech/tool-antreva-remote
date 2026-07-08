Unicode true

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "nsDialogs.nsh"
!include "x64.nsh"

!ifndef OUTFILE
  !define OUTFILE "AntrevaDesk-Setup-0.1.0.exe"
!endif

Name "AntrevaDesk"
OutFile "${OUTFILE}"
RequestExecutionLevel user
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
!define MUI_FINISHPAGE_TEXT "AntrevaDesk setup has finished. If the PowerShell setup window reported an error, review the setup log shown there."

Var ARCH_X64
Var ARCH_X86
Var SelectedArchitecture
Var PortableExe
Var SetupScript

!insertmacro MUI_PAGE_WELCOME
Page custom AntrevaDeskArchitecturePage AntrevaDeskArchitecturePageLeave
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

  DetailPrint "Launching AntrevaDesk managed setup..."
  ExecWait '"powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$SetupScript" -Architecture "$SelectedArchitecture" -PortableExe "$PortableExe"' $0
  ${If} $0 != 0
    SetErrors
    MessageBox MB_ICONSTOP "AntrevaDesk setup did not finish successfully. Exit code: $0.$\r$\n$\r$\nPlease review the AntrevaDesk setup window or log file."
  ${EndIf}
SectionEnd

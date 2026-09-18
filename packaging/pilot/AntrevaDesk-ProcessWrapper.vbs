Option Explicit

If WScript.Arguments.Count = 0 Then WScript.Quit 0
If WScript.Arguments.Count < 4 Then
    WScript.Echo "Usage: AntrevaDesk-ProcessWrapper.vbs output-path executable timeout-seconds [--detached] arguments..."
    WScript.Quit 2
End If

Dim outputPath, executablePath, timeoutSeconds, detached, commandLine, index
Dim shell, process, startedAt, outputText, pid, createStatus
outputPath = WScript.Arguments(0)
executablePath = WScript.Arguments(1)
timeoutSeconds = CInt(WScript.Arguments(2))
detached = False
index = 3
If WScript.Arguments.Count > 3 Then
    If LCase(WScript.Arguments(3)) = "--detached" Then
        detached = True
        index = 4
    End If
End If

commandLine = QuoteArgument(executablePath)
Do While index <= WScript.Arguments.Count - 1
    commandLine = commandLine & " " & QuoteArgument(WScript.Arguments(index))
    index = index + 1
Loop

If detached Then
    ' RustDesk --silent-install copies files, then keeps running to show UI/toasts.
    ' Do not attach stdout pipes or wait for that process to exit.
    createStatus = StartDetachedProcess(commandLine, pid)
    If createStatus <> 0 Or pid = 0 Then
        WriteOutputFile "Failed to start process. WMI status " & createStatus
        WScript.Quit 1
    End If
    WriteOutputFile "PID=" & pid
    WScript.Quit 0
End If

Set shell = CreateObject("WScript.Shell")
Set process = shell.Exec(commandLine)
startedAt = Timer

Do While process.Status = 0
    WScript.Sleep 250
    If Timer < startedAt Then startedAt = startedAt - 86400
    If Timer - startedAt >= timeoutSeconds Then
        process.Terminate
        WriteOutputFile "TIMEOUT: process exceeded " & timeoutSeconds & " seconds."
        WScript.Quit 124
    End If
Loop

outputText = process.StdOut.ReadAll & process.StdErr.ReadAll
WriteOutputFile outputText

If InStr(1, outputText, "Installation failed", vbTextCompare) > 0 Then WScript.Quit 125
If InStr(1, outputText, "Failed with error", vbTextCompare) > 0 Then WScript.Quit 125
WScript.Quit process.ExitCode

' QuoteArgument wraps values that contain whitespace or quotes for CreateProcess.
Function QuoteArgument(ByVal value)
    If InStr(value, " ") = 0 And InStr(value, vbTab) = 0 And InStr(value, """") = 0 Then
        QuoteArgument = value
    Else
        QuoteArgument = """" & Replace(value, """", """""") & """"
    End If
End Function

' WriteOutputFile replaces the wrapper output file with a single ANSI payload.
Sub WriteOutputFile(ByVal text)
    Dim fileSystem, outputFile
    Set fileSystem = CreateObject("Scripting.FileSystemObject")
    Set outputFile = fileSystem.CreateTextFile(outputPath, True, False)
    outputFile.Write text
    outputFile.Close
End Sub

' StartDetachedProcess starts commandLine hidden via WMI and returns the new PID.
Function StartDetachedProcess(ByVal line, ByRef processId)
    Dim wmi, startup, status
    processId = 0
    Set wmi = GetObject("winmgmts:\\.\root\cimv2")
    Set startup = wmi.Get("Win32_ProcessStartup").SpawnInstance_
    startup.ShowWindow = 0
    status = wmi.Get("Win32_Process").Create(line, Null, startup, processId)
    StartDetachedProcess = status
End Function

Option Explicit

If WScript.Arguments.Count = 0 Then
    WScript.Quit 0
End If

If WScript.Arguments.Count <> 5 Then
    WScript.Echo "Usage: AntrevaDesk-Elevate.vbs command setup working-directory run-id result-path"
    WScript.Quit 2
End If

Dim commandPath, setupPath, workingDirectory, runId, resultPath
Dim shellApplication, fileSystem, resultFile, arguments
commandPath = WScript.Arguments(0)
setupPath = WScript.Arguments(1)
workingDirectory = WScript.Arguments(2)
runId = WScript.Arguments(3)
resultPath = WScript.Arguments(4)
arguments = "/d /c call """ & setupPath & """ --elevated """ & runId & """"

On Error Resume Next
Set shellApplication = CreateObject("Shell.Application")
shellApplication.ShellExecute commandPath, arguments, workingDirectory, "runas", 1
If Err.Number <> 0 Then
    Set fileSystem = CreateObject("Scripting.FileSystemObject")
    Set resultFile = fileSystem.CreateTextFile(resultPath, True, False)
    resultFile.WriteLine "STATUS=FAILED"
    resultFile.WriteLine "MESSAGE=Windows administrator approval was not completed."
    resultFile.Close
    WScript.Quit 1
End If
On Error GoTo 0

WScript.Quit 0

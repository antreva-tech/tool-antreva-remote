Option Explicit

If WScript.Arguments.Count = 0 Then WScript.Quit 0
If WScript.Arguments.Count < 4 Then
    WScript.Echo "Usage: AntrevaDesk-ProcessWrapper.vbs output-path executable timeout-seconds arguments..."
    WScript.Quit 2
End If

Dim outputPath, executablePath, timeoutSeconds, commandLine
Dim shell, process, startedAt, fileSystem, outputFile, outputText, index
outputPath = WScript.Arguments(0)
executablePath = WScript.Arguments(1)
timeoutSeconds = CInt(WScript.Arguments(2))
commandLine = QuoteArgument(executablePath)

For index = 3 To WScript.Arguments.Count - 1
    commandLine = commandLine & " " & QuoteArgument(WScript.Arguments(index))
Next

Set shell = CreateObject("WScript.Shell")
Set process = shell.Exec(commandLine)
startedAt = Timer

Do While process.Status = 0
    WScript.Sleep 250
    If Timer < startedAt Then startedAt = startedAt - 86400
    If Timer - startedAt >= timeoutSeconds Then
        process.Terminate
        Set fileSystem = CreateObject("Scripting.FileSystemObject")
        Set outputFile = fileSystem.CreateTextFile(outputPath, True, False)
        outputFile.WriteLine "TIMEOUT: process exceeded " & timeoutSeconds & " seconds."
        outputFile.Close
        WScript.Quit 124
    End If
Loop

outputText = process.StdOut.ReadAll & process.StdErr.ReadAll
Set fileSystem = CreateObject("Scripting.FileSystemObject")
Set outputFile = fileSystem.CreateTextFile(outputPath, True, False)
outputFile.Write outputText
outputFile.Close

If InStr(1, outputText, "Installation failed", vbTextCompare) > 0 Then WScript.Quit 125
If InStr(1, outputText, "Failed with error", vbTextCompare) > 0 Then WScript.Quit 125
WScript.Quit process.ExitCode

Function QuoteArgument(ByVal value)
    If InStr(value, " ") = 0 And InStr(value, vbTab) = 0 And InStr(value, """") = 0 Then
        QuoteArgument = value
    Else
        QuoteArgument = """" & Replace(value, """", """""") & """"
    End If
End Function

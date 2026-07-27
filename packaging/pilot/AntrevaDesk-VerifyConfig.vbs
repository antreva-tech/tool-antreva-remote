Option Explicit

If WScript.Arguments.Count = 0 Then WScript.Quit 0
If WScript.Arguments.Count < 2 Then
    WScript.Echo "Usage: AntrevaDesk-VerifyConfig.vbs --options file key value... | --password file"
    WScript.Quit 2
End If

Dim mode, configPath, values
mode = LCase(WScript.Arguments(0))
configPath = WScript.Arguments(1)
Set values = ReadAssignments(configPath)

If values Is Nothing Then
    WScript.Echo "Configuration file is missing: " & configPath
    WScript.Quit 3
End If

If mode = "--password" Then
    If Not values.Exists("password") Then WScript.Quit 20
    If Len(values("password")) < 3 Or Left(values("password"), 2) <> "01" Then WScript.Quit 21
    If Not values.Exists("salt") Or Len(values("salt")) = 0 Then WScript.Quit 22
    WScript.Echo "Password and salt persistence are valid."
    WScript.Quit 0
End If

If mode <> "--options" Then WScript.Quit 2
If (WScript.Arguments.Count - 2) Mod 2 <> 0 Then WScript.Quit 2

Dim index, optionName, expectedValue
For index = 2 To WScript.Arguments.Count - 1 Step 2
    optionName = LCase(WScript.Arguments(index))
    expectedValue = WScript.Arguments(index + 1)
    If Not values.Exists(optionName) Then
        WScript.Echo "Missing option: " & optionName
        WScript.Quit 30
    End If
    If values(optionName) <> expectedValue Then
        WScript.Echo "Option mismatch: " & optionName
        WScript.Quit 31
    End If
    If optionName = "relay-server" And Len(expectedValue) = 0 Then
        WScript.Echo "Relay server must not be blank."
        WScript.Quit 32
    End If
Next

WScript.Echo "Exact configuration persistence is valid."
WScript.Quit 0

Function ReadAssignments(ByVal path)
    Dim fileSystem, result, stream, line, equalsAt, key, value
    Set fileSystem = CreateObject("Scripting.FileSystemObject")
    If Not fileSystem.FileExists(path) Then
        Set ReadAssignments = Nothing
        Exit Function
    End If

    Set result = CreateObject("Scripting.Dictionary")
    result.CompareMode = 1
    Set stream = fileSystem.OpenTextFile(path, 1, False)
    Do Until stream.AtEndOfStream
        line = Trim(stream.ReadLine)
        equalsAt = InStr(1, line, "=")
        If equalsAt > 1 Then
            key = LCase(Trim(Left(line, equalsAt - 1)))
            value = Trim(Mid(line, equalsAt + 1))
            If Len(value) >= 2 Then
                If (Left(value, 1) = "'" And Right(value, 1) = "'") Or (Left(value, 1) = """" And Right(value, 1) = """") Then
                    value = Mid(value, 2, Len(value) - 2)
                End If
            End If
            result(key) = value
        End If
    Loop
    stream.Close
    Set ReadAssignments = result
End Function

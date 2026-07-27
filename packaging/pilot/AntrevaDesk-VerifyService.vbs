Option Explicit

If WScript.Arguments.Count = 0 Then
    WScript.Quit 0
End If

Dim expectedPath, serviceFound, serviceState, serviceStartMode, servicePath
Dim services, service

If LCase(WScript.Arguments(0)) = "--test-fields" Then
    If WScript.Arguments.Count <> 6 Then
        WScript.Echo "Expected 6 test arguments but received " & WScript.Arguments.Count & "."
        WScript.Quit 2
    End If
    expectedPath = WScript.Arguments(1)
    serviceFound = (UCase(WScript.Arguments(2)) = "Y")
    serviceState = WScript.Arguments(3)
    serviceStartMode = WScript.Arguments(4)
    servicePath = WScript.Arguments(5)
Else
    expectedPath = WScript.Arguments(0)
    serviceFound = False
    Set services = GetObject("winmgmts:\\.\root\cimv2").ExecQuery("SELECT Name, State, StartMode, PathName FROM Win32_Service WHERE Name='RustDesk'")
    For Each service In services
        serviceFound = True
        serviceState = service.State
        serviceStartMode = service.StartMode
        servicePath = service.PathName
    Next
End If

If Not serviceFound Then
    WScript.Echo "RustDesk service is missing."
    WScript.Quit 10
End If
If LCase(serviceState) <> "running" Then
    WScript.Echo "RustDesk service is not running."
    WScript.Quit 11
End If
If LCase(serviceStartMode) <> "auto" Then
    WScript.Echo "RustDesk service start mode is not automatic."
    WScript.Quit 12
End If
If LCase(ExtractExecutable(servicePath)) <> LCase(expectedPath) Then
    WScript.Echo "RustDesk service image path does not match the installed executable."
    WScript.Quit 13
End If

WScript.Echo "RustDesk service state, start mode, and image path are valid."
WScript.Quit 0

Function ExtractExecutable(ByVal serviceCommand)
    Dim text, closingQuote, firstSpace
    text = Trim(serviceCommand)
    If Left(text, 1) = """" Then
        closingQuote = InStr(2, text, """")
        If closingQuote = 0 Then
            ExtractExecutable = ""
        Else
            ExtractExecutable = Mid(text, 2, closingQuote - 2)
        End If
    Else
        firstSpace = InStr(1, text, " ")
        If firstSpace = 0 Then
            ExtractExecutable = text
        Else
            ExtractExecutable = Left(text, firstSpace - 1)
        End If
    End If
End Function

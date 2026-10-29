Option Explicit

Dim shell, fso, root, ps1, powershell, rc
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

root = fso.GetParentFolderName(WScript.ScriptFullName)
ps1 = fso.BuildPath(root, "Install-Production-Preview-Sync-Layout.ps1")
powershell = shell.ExpandEnvironmentStrings("%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe")

If Not fso.FileExists(ps1) Then
    MsgBox "Missing production-layout installer:" & vbCrLf & ps1, vbCritical, "MSB Preview Sync Production Setup"
    WScript.Quit 2
End If

rc = shell.Run(Chr(34) & powershell & Chr(34) & _
    " -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File " & _
    Chr(34) & ps1 & Chr(34), 1, True)

WScript.Quit rc

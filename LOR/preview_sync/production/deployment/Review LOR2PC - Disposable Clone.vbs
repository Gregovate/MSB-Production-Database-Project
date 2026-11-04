Option Explicit
Dim shell, fso, script, powershell, rc
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
script = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "Review-LOR2PC-Clone.ps1")
powershell = shell.ExpandEnvironmentStrings("%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe")
rc = shell.Run(Chr(34) & powershell & Chr(34) & " -NoLogo -NoProfile -NoExit -ExecutionPolicy Bypass -STA -File " & Chr(34) & script & Chr(34), 1, True)
WScript.Quit rc

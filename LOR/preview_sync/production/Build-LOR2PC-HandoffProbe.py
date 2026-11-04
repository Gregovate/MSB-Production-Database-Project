"""Prepare a standalone read-only handoff diagnostic from a clean commit."""
from pathlib import Path
import subprocess
import sys
ROOT = Path(__file__).resolve().parents[3]
if subprocess.check_output(['git','status','--porcelain'],cwd=ROOT).strip():
    raise SystemExit('BLOCK: exact clean committed source required')
commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
source=Path(__file__).with_name('Update_MSB_Previews.ps1').read_text()
functions=source[source.index('function Write-HandoffTrace {'):source.index('function Get-CurrentAcceptedSource {')]
output=Path(sys.argv[1])
if output.exists(): raise SystemExit('BLOCK: diagnostic output already exists')
header="""# Test-LOR2PC-Handoff.ps1 - read-only transport probe. Source: """+commit+"""
# No installation, registry edits, preview reads/writes, or source promotion.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$LogFolder=Join-Path $env:LOCALAPPDATA ('MSB\\LOR2PC-Diagnostics\\'+[guid]::NewGuid().ToString('N'))
function Invoke-SyncEvents {}
"""
footer="""
Write-Host 'Opening the protected MSB page for a read-only browser handoff test.'
Write-Host ('Diagnostic folder: '+$LogFolder)
try {
    $received=Receive-BrowserSource
    $document=$received | ConvertFrom-Json
    Write-Host 'HANDOFF RECEIVED. This proves transport only; source/master validation and PC synchronization were not run.'
} catch {
    Write-Host ('HANDOFF HOLD: '+$_.Exception.Message)
    exit 2
} finally {
    Write-Host ('Return this log: '+(Join-Path $LogFolder 'browser-handoff.log'))
}
"""
output.write_text(header+functions+footer,encoding='utf-8-sig')
print('Prepared diagnostic from '+commit)

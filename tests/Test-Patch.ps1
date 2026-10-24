#requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string] $FixturePath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$patch = Join-Path (Split-Path $PSScriptRoot -Parent) 'patch.ps1'
$originalHash = '6B6E1260CB5A1D6A303855F1C60CAB3D0BC1AEBBA7E40A964180188B271E7386'
$patchedHash = 'BA7585206D97D63AD6F48CDF5FE3F79757B405990D85D1009E1EE19EDF4272A9'
if ((Get-FileHash -LiteralPath $FixturePath).Hash -ne $originalHash) { throw 'Provide the unmodified official fixture.' }
$run = Join-Path ([IO.Path]::GetTempPath()) ('pcl-patch-test-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($run) | Out-Null
$file = Join-Path $run (([string][char]0x6D4B) + [char]0x8BD5 + ' PCL [1].exe')
[IO.File]::Copy((Get-Item -LiteralPath $FixturePath).FullName, $file)
function Assert([bool] $Condition, [string] $Message) { if (!$Condition) { throw $Message } }
function Assert-Rejected([scriptblock] $Action) {
    $rejected = $false
    try { & $Action | Out-Null } catch { $rejected = $true }
    Assert $rejected 'Expected the operation to be rejected.'
}
Assert ((& $patch -Path $file -Check).State -eq 'Original') 'Check original failed.'
Assert (!(Test-Path -LiteralPath ($file + '.pcl-download-patch.bak'))) 'Check wrote a backup.'
& $patch -Path ('"' + $file + '"')
Assert ((Get-FileHash -LiteralPath $file).Hash -eq $patchedHash) 'Patched hash mismatch.'
Assert ((Get-FileHash -LiteralPath ($file + '.pcl-download-patch.bak')).Hash -eq $originalHash) 'Backup hash mismatch.'
& $patch -Path $file
Assert ((Get-FileHash -LiteralPath $file).Hash -eq $patchedHash) 'Repeat changed the patch.'
& $patch -Path $file -Restore
Assert ((Get-FileHash -LiteralPath $file).Hash -eq $originalHash) 'Restore mismatch.'

$bad = Join-Path $run 'unsupported.exe'
[IO.File]::WriteAllBytes($bad, [byte[]](0x4d,0x5a,0,1))
$badHash = (Get-FileHash -LiteralPath $bad).Hash
Assert-Rejected { & $patch -Path $bad }
Assert ((Get-FileHash -LiteralPath $bad).Hash -eq $badHash) 'Rejected file changed.'
Assert (!(Test-Path -LiteralPath ($bad + '.pcl-download-patch.bak'))) 'Rejected file backed up.'
Assert-Rejected { & $patch -Path $run }

[IO.File]::WriteAllText($file + '.pcl-download-patch.bak', 'unrelated backup')
Assert-Rejected { & $patch -Path $file }
Assert ((Get-FileHash -LiteralPath $file).Hash -eq $originalHash) 'Bad backup changed target.'

# Exclusive lock: no replacement should happen while another writer owns the file.
$locked = Join-Path $run 'locked.exe'
[IO.File]::Copy((Get-Item -LiteralPath $FixturePath).FullName, $locked)
$handle = [IO.File]::Open($locked, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
try { Assert-Rejected { & $patch -Path $locked } } finally { $handle.Dispose() }
Assert ((Get-FileHash -LiteralPath $locked).Hash -eq $originalHash) 'Locked target changed.'
Write-Host ('PASS: compatibility, quoted Unicode paths, patch, repeat, backup, restore, invalid input, conflicting backup, locked target. Artifacts: ' + $run)

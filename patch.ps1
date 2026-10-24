#requires -Version 5.1
<#
.SYNOPSIS
Restore the Minecraft version-list loader in the official PCL 2.99.0.0 executable.
.PARAMETER Path
The launcher executable, not its directory. Prompts when omitted.
.PARAMETER Restore
Restore the verified original executable from the adjacent backup.
.PARAMETER Check
Report compatibility without writing anything.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string] $Path,
    [switch] $Restore,
    [switch] $Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($Restore -and $Check) { throw 'Use either -Restore or -Check.' }

# This manifest is specific to the official 2.99.0.0 release, including its resources.
$originalHash = '6B6E1260CB5A1D6A303855F1C60CAB3D0BC1AEBBA7E40A964180188B271E7386'
$patchOffset = 180442 # LoaderInit: file offset 0x2C0B4 + 12-byte header + IL_001A
$before = [byte[]](0x72,0x33,0x47,0x01,0x70,0x7e,0xfb,0x09,0x00,0x04,0x2c,0x07,
    0x7e,0xfb,0x09,0x00,0x04,0x2b,0x16,0x7e,0xf9,0x09,0x00,0x04,0xfe,0x06,
    0x67,0x14,0x00,0x06,0x73,0x8d,0x05,0x00,0x0a,0x25,0x80,0xfb,0x09,0x00,
    0x04,0x14,0x18,0x73,0x8e,0x05,0x00,0x0a)
$after = New-Object byte[] $before.Length
# ldsfld PCL.ModDownload::DlClientListLoader; preserve all remaining offsets with nops.
[Array]::Copy([byte[]](0x7e,0x0f,0x04,0x00,0x04), 0, $after, 0, 5)

function Get-BytesHash([byte[]] $Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($Bytes)).Replace('-', '') }
    finally { $sha.Dispose() }
}

function Test-Slice([byte[]] $Bytes, [byte[]] $Expected) {
    if ($Bytes.Length -lt ($patchOffset + $Expected.Length)) { return $false }
    for ($i = 0; $i -lt $Expected.Length; $i++) {
        if ($Bytes[$patchOffset + $i] -ne $Expected[$i]) { return $false }
    }
    return $true
}

function Get-PatchState([byte[]] $Bytes) {
    if ((Get-BytesHash $Bytes) -eq $originalHash) { return 'Original' }
    if (Test-Slice $Bytes $after) {
        $candidate = [byte[]] $Bytes.Clone()
        [Array]::Copy($before, 0, $candidate, $patchOffset, $before.Length)
        if ((Get-BytesHash $candidate) -eq $originalHash) { return 'Patched' }
    }
    throw 'Unsupported or modified executable. Only the verified official PCL 2.99.0.0 build is supported; no files were changed.'
}

if ([string]::IsNullOrWhiteSpace($Path)) { $Path = Read-Host 'PCL executable file path' }
$Path = $Path.Trim()
if ($Path.Length -ge 2 -and (($Path.StartsWith('"') -and $Path.EndsWith('"')) -or
        ($Path.StartsWith("'") -and $Path.EndsWith("'")))) {
    $Path = $Path.Substring(1, $Path.Length - 2)
}
$item = Get-Item -LiteralPath $Path -Force
if ($item.PSIsContainer -or $item.Extension -ine '.exe') { throw 'Path must point to a .exe file, not a directory.' }
if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Symbolic links are not supported. Use the actual executable path.' }
$target = $item.FullName
$backup = $target + '.pcl-download-patch.bak'
$bytes = [IO.File]::ReadAllBytes($target)
$state = Get-PatchState $bytes

if ($Check) {
    return [pscustomobject]@{ State = $state; Path = $target; SHA256 = (Get-BytesHash $bytes) }
}
if (($Restore -and $state -eq 'Original') -or (!$Restore -and $state -eq 'Patched')) {
    Write-Host ('Already {0}; nothing changed.' -f $state.ToLowerInvariant())
    return
}

# Do not rename an executable that is currently running.
foreach ($process in @(Get-Process -ErrorAction SilentlyContinue)) {
    try {
        if ($process.Path -and [string]::Equals($process.Path, $target, [StringComparison]::OrdinalIgnoreCase)) {
            throw ('Close the launcher before applying/restoring the patch (PID {0}).' -f $process.Id)
        }
    } catch [System.ComponentModel.Win32Exception] {
        # Some unrelated system processes do not expose their executable path.
    }
}

if ($Restore) {
    if (!(Test-Path -LiteralPath $backup -PathType Leaf)) { throw 'The original backup is missing. Restore was cancelled.' }
    $replacement = [IO.File]::ReadAllBytes($backup)
    if ((Get-BytesHash $replacement) -ne $originalHash) { throw 'Backup verification failed. Restore was cancelled.' }
} else {
    if (!(Test-Slice $bytes $before)) { throw 'Patch instruction verification failed.' }
    $replacement = [byte[]] $bytes.Clone()
    [Array]::Copy($after, 0, $replacement, $patchOffset, $after.Length)
    if (Test-Path -LiteralPath $backup) {
        if (!(Test-Path -LiteralPath $backup -PathType Leaf)) { throw 'The backup path is not a regular file.' }
        if ((Get-BytesHash ([IO.File]::ReadAllBytes($backup))) -ne $originalHash) {
            throw 'A different backup already exists. Preserve it elsewhere before retrying.'
        }
    } else {
        # CreateNew refuses to overwrite any existing backup, including racing writers.
        $backupStream = [IO.File]::Open($backup, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try { $backupStream.Write($bytes, 0, $bytes.Length); $backupStream.Flush($true) }
        finally { $backupStream.Dispose() }
        if ((Get-BytesHash ([IO.File]::ReadAllBytes($backup))) -ne $originalHash) { throw 'Backup verification failed.' }
    }
}

# Stage beside the target, then use same-volume atomic replacement. Preserve the backup.
$stage = Join-Path $item.DirectoryName ('.pcl-download-patch-' + [Guid]::NewGuid().ToString('N') + '.tmp')
try {
    [IO.File]::WriteAllBytes($stage, $replacement)
    if ((Get-BytesHash ([IO.File]::ReadAllBytes($stage))) -ne (Get-BytesHash $replacement)) { throw 'Staged file verification failed.' }
    if ((Get-BytesHash ([IO.File]::ReadAllBytes($target))) -ne (Get-BytesHash $bytes)) { throw 'The launcher changed while preparing the patch; retry after closing it.' }
    # Check write access and conflicting open handles before replacement.
    $probe = [IO.File]::Open($target, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $probe.Dispose()
    [IO.File]::Replace($stage, $target, [System.Management.Automation.Language.NullString]::Value)
    if ((Get-BytesHash ([IO.File]::ReadAllBytes($target))) -ne (Get-BytesHash $replacement)) {
        throw ('Final verification failed. The verified original is at: ' + $backup)
    }
} finally {
    if ([IO.File]::Exists($stage)) { [IO.File]::Delete($stage) }
}

Write-Host $(if ($Restore) { 'Original launcher restored.' } else { 'Minecraft download patch applied. You can start PCL now.' })
Write-Host ('Verified original backup: ' + $backup)

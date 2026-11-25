#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Install','Verify','Restore')][string]$Action = 'Install',
    [string]$GameDir
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$packageRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$replaceNames = @('cg.pak','data.pak','KaigenSeito.exe','script.pak','system.dll','system.pak')
$allNames = @($replaceNames) + @('ko.dll')

# Adapted from the existing DraKoI release installer: canonical paths,
# reparse ancestry rejection, SHA-256 verification and atomic replacement.
function Get-CanonicalPath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { throw 'Path cannot be empty.' }
    $full = [IO.Path]::GetFullPath($Path)
    if ($full.Length -gt [IO.Path]::GetPathRoot($full).Length) { $full = $full.TrimEnd('\','/') }
    return $full
}
function Assert-NoReparseAncestry([string]$Path) {
    $current = Get-CanonicalPath $Path
    while (-not [string]::IsNullOrEmpty($current)) {
        if (Test-Path -LiteralPath $current) {
            if ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Linked paths are not supported: $current"
            }
        }
        $parent = [IO.Path]::GetDirectoryName($current)
        if ($parent -eq $current) { break }
        $current = $parent
    }
}
function Get-SafeChild([string]$Root, [string]$Relative) {
    if ([IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|[\\/])\.\.([\\/]|$)|:') { throw 'Unsafe relative path.' }
    $base = (Get-CanonicalPath $Root).TrimEnd('\') + '\'
    $full = [IO.Path]::GetFullPath((Join-Path $Root $Relative))
    if (-not $full.StartsWith($base,[StringComparison]::OrdinalIgnoreCase)) { throw 'Path escapes its root.' }
    Assert-NoReparseAncestry $full
    return $full
}
function Get-Sha256([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing file: $Path" }
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','').ToLowerInvariant() }
    finally { $stream.Dispose(); $sha.Dispose() }
}
function Assert-File([string]$Path, $Expected) {
    Assert-NoReparseAncestry $Path
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing file: $Path" }
    if ((Get-Item -LiteralPath $Path).Length -ne $Expected.size -or (Get-Sha256 $Path) -ne $Expected.sha256) {
        throw "File does not match this release: $Path"
    }
}
function Write-Json([string]$Path, $Value) {
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
}
function Assert-GameStopped {
    foreach ($process in @(Get-Process -Name 'KaigenSeito' -ErrorAction SilentlyContinue)) {
        try { $processPath = $process.Path } catch { throw 'Cannot inspect a running game. Close the game first.' }
        if ([string]::IsNullOrWhiteSpace($processPath) -or [string]::Equals($processPath,(Join-Path $GameDir 'KaigenSeito.exe'),[StringComparison]::OrdinalIgnoreCase)) {
            throw 'Close the target game before installing or restoring.'
        }
    }
    foreach ($name in $allNames) {
        $path = Get-SafeChild $GameDir $name
        if (Test-Path -LiteralPath $path) {
            $stream = [IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
            $stream.Dispose()
        }
    }
}
function Set-VerifiedFile([string]$Source, [string]$Destination, $Expected) {
    $temporary = $Destination + '.kaigen-tmp-' + [Guid]::NewGuid().ToString('N')
    Assert-NoReparseAncestry $Destination
    try {
        [IO.File]::Copy($Source,$temporary,$false)
        Assert-File $temporary $Expected
        if (Test-Path -LiteralPath $Destination -PathType Leaf) {
            $previous = $temporary + '.previous'
            [IO.File]::Replace($temporary,$Destination,$previous,$true)
            Assert-File $Destination $Expected
            try { Remove-Item -LiteralPath $previous -Force -ErrorAction Stop } catch {}
        }
        else { [IO.File]::Move($temporary,$Destination) }
        Assert-File $Destination $Expected
    } finally {
        if (Test-Path -LiteralPath $temporary -PathType Leaf) { Remove-Item -LiteralPath $temporary -Force }
    }
}
function Assert-OriginalBackup {
    $stamp = Get-SafeChild $backupRoot 'ready.json'
    if (-not (Test-Path -LiteralPath $stamp -PathType Leaf)) { throw 'Incomplete backup. No game files will be changed. Keep the backup and inspect it.' }
    $record = Get-Content -LiteralPath $stamp -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($record.release -ne $manifest.version) { throw 'Backup belongs to a different release.' }
    foreach ($entry in $manifest.files) {
        if ($entry.kind -eq 'delta') { Assert-File (Get-SafeChild $backupRoot $entry.path) $entry.source }
    }
}
function Restore-OriginalFiles {
    Assert-OriginalBackup
    foreach ($entry in $manifest.files) {
        if ($entry.kind -eq 'delta') {
            Set-VerifiedFile (Get-SafeChild $backupRoot $entry.path) (Get-SafeChild $GameDir $entry.path) $entry.source
        }
    }
    $added = Get-SafeChild $GameDir 'ko.dll'
    if (Test-Path -LiteralPath $added) {
        Assert-File $added ($manifest.files | Where-Object path -eq 'ko.dll').target
        Remove-Item -LiteralPath $added -Force
    }
}
try {
    if (-not $GameDir) {
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object Windows.Forms.FolderBrowserDialog
        $dialog.Description = 'KaigenSeito.exe가 있는 게임 폴더를 선택하세요.'
        $dialog.ShowNewFolderButton = $false
        try {
            if ($dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { throw 'Cancelled.' }
            $GameDir = $dialog.SelectedPath
        } finally { $dialog.Dispose() }
    }
    $GameDir = Get-CanonicalPath $GameDir
    Assert-NoReparseAncestry $GameDir
    if (-not (Test-Path -LiteralPath $GameDir -PathType Container)) { throw 'Game directory does not exist.' }
    if ($GameDir -eq [IO.Path]::GetPathRoot($GameDir)) { throw 'Select the game directory, not a drive root.' }
    $manifest = Get-Content -LiteralPath (Get-SafeChild $packageRoot 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.schema -ne 'kaigen-seito-korean-hdiff-v1') { throw 'Unsupported manifest.' }
    if (@($manifest.files).Count -ne 7 -or @($manifest.files.path | Sort-Object -Unique).Count -ne 7) { throw 'Invalid file list.' }
    foreach ($entry in $manifest.files) {
        if ($entry.path -notin $allNames -or $entry.target.sha256 -notmatch '^[a-f0-9]{64}$') { throw 'Invalid target.' }
        if ($entry.path -eq 'ko.dll') {
            if ($entry.kind -ne 'added' -or $entry.payload -ne 'files/ko.dll') { throw 'Invalid added file.' }
        } elseif ($entry.kind -ne 'delta' -or $entry.payload -ne ('patches/' + $entry.path + '.hdiff') -or $entry.source.sha256 -notmatch '^[a-f0-9]{64}$') { throw 'Invalid delta.' }
        Assert-File (Get-SafeChild $packageRoot $entry.payload) $entry.patch
    }
    if ($manifest.patcher.path -ne 'tools/hpatchz.exe') { throw 'Invalid patcher path.' }
    $patcher = Get-SafeChild $packageRoot $manifest.patcher.path
    Assert-File $patcher $manifest.patcher
    foreach ($anchor in $manifest.unchanged) {
        if ($anchor.path -notin @('sound.pak','mpeg.pak')) { throw 'Invalid anchor.' }
        Assert-File (Get-SafeChild $GameDir $anchor.path) $anchor
    }
    if ($Action -eq 'Verify') {
        foreach ($entry in $manifest.files) { Assert-File (Get-SafeChild $GameDir $entry.path) $entry.target }
        Write-Output 'VERIFY PASS: all release files match. SAVE and settings were not changed.'
        exit 0
    }
    Assert-GameStopped
    $lockPath = Get-SafeChild $GameDir '.kaigen-ko-install.lock'
    $lock = [IO.File]::Open($lockPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $stageRoot = $null
    try {
        $backupRoot = Get-SafeChild $GameDir '.kaigen-ko-backup-r4a'
        if ($Action -eq 'Restore') {
            Assert-OriginalBackup
            foreach ($entry in $manifest.files) {
                $path = Get-SafeChild $GameDir $entry.path
                if ($entry.kind -eq 'added' -and -not (Test-Path -LiteralPath $path)) { continue }
                $hash = Get-Sha256 $path
                if ($hash -ne $entry.target.sha256 -and ($entry.kind -ne 'delta' -or $hash -ne $entry.source.sha256)) { throw "Unknown modified file; restore stopped: $($entry.path)" }
            }
            Restore-OriginalFiles
            Write-Output 'RESTORE PASS: original files restored. SAVE and settings were not changed; backup retained.'
            exit 0
        }
        $alreadyInstalled = $true
        foreach ($entry in $manifest.files) {
            $path = Get-SafeChild $GameDir $entry.path
            if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Sha256 $path) -ne $entry.target.sha256) { $alreadyInstalled = $false }
        }
        if ($alreadyInstalled) { Write-Output 'ALREADY INSTALLED: this exact release is present.'; exit 0 }
        foreach ($entry in $manifest.files) {
            $path = Get-SafeChild $GameDir $entry.path
            if ($entry.kind -eq 'delta') { Assert-File $path $entry.source }
            elseif (Test-Path -LiteralPath $path) { throw 'An existing ko.dll was found. Restore the previous patch first.' }
        }
        if (Test-Path -LiteralPath $backupRoot) { Assert-OriginalBackup }
        else {
            New-Item -ItemType Directory -Path $backupRoot | Out-Null
            foreach ($entry in $manifest.files) {
                if ($entry.kind -eq 'delta') {
                    $destination = Get-SafeChild $backupRoot $entry.path
                    [IO.File]::Copy((Get-SafeChild $GameDir $entry.path),$destination,$false)
                    Assert-File $destination $entry.source
                }
            }
            Write-Json (Get-SafeChild $backupRoot 'ready.json') @{release=$manifest.version; created_utc=[DateTime]::UtcNow.ToString('o')}
        }
        $stageRoot = Get-SafeChild $backupRoot ('stage-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $stageRoot | Out-Null
        foreach ($entry in $manifest.files) {
            $target = Get-SafeChild $stageRoot $entry.path
            $payload = Get-SafeChild $packageRoot $entry.payload
            if ($entry.kind -eq 'delta') {
                & $patcher (Get-SafeChild $backupRoot $entry.path) $payload $target | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "Patch tool failed: $($entry.path)" }
            } else { [IO.File]::Copy($payload,$target,$false) }
            Assert-File $target $entry.target
        }
        Assert-GameStopped
        try {
            foreach ($entry in $manifest.files) {
                Set-VerifiedFile (Get-SafeChild $stageRoot $entry.path) (Get-SafeChild $GameDir $entry.path) $entry.target
            }
        } catch {
            $installError = $_
            try { Restore-OriginalFiles } catch { throw "Install failed and rollback was interrupted. Keep the backup and run Restore. $($_.Exception.Message)" }
            throw "Install failed; original files restored. $($installError.Exception.Message)"
        }
        Write-Output 'INSTALL PASS: Korean patch installed and verified. SAVE and settings were not changed.'
    } finally {
        try {
        if ($null -ne $stageRoot -and (Test-Path -LiteralPath $stageRoot)) {
            # Only known staged files are removed; no recursive deletion or wildcard.
            foreach ($name in $allNames) {
                $staged = Get-SafeChild $stageRoot $name
                if (Test-Path -LiteralPath $staged -PathType Leaf) { Remove-Item -LiteralPath $staged -Force }
            }
            if (@(Get-ChildItem -LiteralPath $stageRoot -Force).Count -eq 0) { Remove-Item -LiteralPath $stageRoot }
        }
        } finally {
            $lock.Dispose()
            Remove-Item -LiteralPath $lockPath -Force
        }
    }
} catch {
    Write-Error $_
    exit 1
}
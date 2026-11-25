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
    if ([string]::IsNullOrWhiteSpace($Path)) { throw '경로가 비어 있습니다.' }
    $full = [IO.Path]::GetFullPath($Path)
    if ($full.Length -gt [IO.Path]::GetPathRoot($full).Length) { $full = $full.TrimEnd('\','/') }
    return $full
}
function Assert-NoReparseAncestry([string]$Path) {
    $current = Get-CanonicalPath $Path
    while (-not [string]::IsNullOrEmpty($current)) {
        if (Test-Path -LiteralPath $current) {
            if ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "링크·정션을 거친 경로는 지원하지 않습니다: $current"
            }
        }
        $parent = [IO.Path]::GetDirectoryName($current)
        if ($parent -eq $current) { break }
        $current = $parent
    }
}
function Get-SafeChild([string]$Root, [string]$Relative) {
    if ([IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|[\\/])\.\.([\\/]|$)|:') { throw '안전하지 않은 상대 경로입니다.' }
    $base = (Get-CanonicalPath $Root).TrimEnd('\') + '\'
    $full = [IO.Path]::GetFullPath((Join-Path $Root $Relative))
    if (-not $full.StartsWith($base,[StringComparison]::OrdinalIgnoreCase)) { throw '경로가 대상 폴더 밖을 가리킵니다.' }
    Assert-NoReparseAncestry $full
    return $full
}
function Get-Sha256([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "파일이 없습니다: $Path" }
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','').ToLowerInvariant() }
    finally { $stream.Dispose(); $sha.Dispose() }
}
function Assert-File([string]$Path, $Expected) {
    Assert-NoReparseAncestry $Path
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "파일이 없습니다: $Path" }
    if ((Get-Item -LiteralPath $Path).Length -ne $Expected.size -or (Get-Sha256 $Path) -ne $Expected.sha256) {
        throw "이 패치가 아는 파일이 아닙니다(크기·해시 불일치): $Path"
    }
}
function Write-Json([string]$Path, $Value) {
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
}
function Assert-GameStopped {
    foreach ($process in @(Get-Process -Name 'KaigenSeito' -ErrorAction SilentlyContinue)) {
        try { $processPath = $process.Path } catch { throw '실행 중인 게임을 확인할 수 없습니다. 게임을 먼저 종료하세요.' }
        if ([string]::IsNullOrWhiteSpace($processPath) -or [string]::Equals($processPath,(Join-Path $GameDir 'KaigenSeito.exe'),[StringComparison]::OrdinalIgnoreCase)) {
            throw '설치·복원 전에 게임을 종료하세요.'
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
    if (-not (Test-Path -LiteralPath $stamp -PathType Leaf)) { throw '백업이 불완전합니다. 게임 파일은 바꾸지 않았습니다. 백업 폴더를 지우지 말고 확인하세요.' }
    # The backup holds only the original files, so it serves every release whose
    # source hashes it matches; a later release upgrades from it directly.
    foreach ($entry in $manifest.files) {
        if ($entry.kind -eq 'delta') { Assert-File (Get-SafeChild $backupRoot $entry.path) $entry.source }
    }
}
function Get-KnownState($entry, [string]$path) {
    # original | current | previous | missing | unknown
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return 'missing' }
    $hash = Get-Sha256 $path
    if ($hash -eq $entry.target.sha256) { return 'current' }
    if ($entry.kind -eq 'delta' -and $hash -eq $entry.source.sha256) { return 'original' }
    foreach ($previous in @($manifest.previous)) {
        if ($previous.files.($entry.path) -eq $hash) { return 'previous' }
    }
    return 'unknown'
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
        $state = Get-KnownState ($manifest.files | Where-Object path -eq 'ko.dll') $added
        if ($state -notin @('current','previous')) { throw '알 수 없는 ko.dll 이 있어 지우지 않았습니다.' }
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
            if ($dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { throw '취소했습니다.' }
            $GameDir = $dialog.SelectedPath
        } finally { $dialog.Dispose() }
    }
    $GameDir = Get-CanonicalPath $GameDir
    Assert-NoReparseAncestry $GameDir
    if (-not (Test-Path -LiteralPath $GameDir -PathType Container)) { throw '게임 폴더가 없습니다.' }
    if ($GameDir -eq [IO.Path]::GetPathRoot($GameDir)) { throw '드라이브 최상위가 아니라 게임 폴더를 선택하세요.' }
    $manifest = Get-Content -LiteralPath (Get-SafeChild $packageRoot 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.schema -ne 'kaigen-seito-korean-hdiff-v1') { throw '지원하지 않는 manifest 입니다.' }
    if (@($manifest.files).Count -ne 7 -or @($manifest.files.path | Sort-Object -Unique).Count -ne 7) { throw '파일 목록이 잘못되었습니다.' }
    foreach ($entry in $manifest.files) {
        if ($entry.path -notin $allNames -or $entry.target.sha256 -notmatch '^[a-f0-9]{64}$') { throw '대상 정보가 잘못되었습니다.' }
        if ($entry.path -eq 'ko.dll') {
            if ($entry.kind -ne 'added' -or $entry.payload -ne 'files/ko.dll') { throw '추가 파일 정보가 잘못되었습니다.' }
        } elseif ($entry.kind -ne 'delta' -or $entry.payload -ne ('patches/' + $entry.path + '.hdiff') -or $entry.source.sha256 -notmatch '^[a-f0-9]{64}$') { throw '차분 정보가 잘못되었습니다.' }
        Assert-File (Get-SafeChild $packageRoot $entry.payload) $entry.patch
    }
    if ($manifest.patcher.path -ne 'tools/hpatchz.exe') { throw '패치 도구 경로가 잘못되었습니다.' }
    $patcher = Get-SafeChild $packageRoot $manifest.patcher.path
    Assert-File $patcher $manifest.patcher
    foreach ($anchor in $manifest.unchanged) {
        if ($anchor.path -notin @('sound.pak','mpeg.pak')) { throw '확인용 원본 정보가 잘못되었습니다.' }
        Assert-File (Get-SafeChild $GameDir $anchor.path) $anchor
    }
    if ($Action -eq 'Verify') {
        foreach ($entry in $manifest.files) { Assert-File (Get-SafeChild $GameDir $entry.path) $entry.target }
        Write-Output "확인 통과: 모든 파일이 이 판($($manifest.version))과 일치합니다. 저장과 설정은 건드리지 않았습니다."
        exit 0
    }
    Assert-GameStopped
    $lockPath = Get-SafeChild $GameDir '.kaigen-ko-install.lock'
    $lock = [IO.File]::Open($lockPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $stageRoot = $null
    try {
        $backupRoot = Get-SafeChild $GameDir '.kaigen-ko-backup'
        # r4a named its backup after the release; it holds the same original files.
        $releaseNamedBackup = Get-SafeChild $GameDir '.kaigen-ko-backup-r4a'
        if (-not (Test-Path -LiteralPath $backupRoot) -and (Test-Path -LiteralPath $releaseNamedBackup)) {
            [IO.Directory]::Move($releaseNamedBackup,$backupRoot)
        }
        if ($Action -eq 'Restore') {
            Assert-OriginalBackup
            foreach ($entry in $manifest.files) {
                $path = Get-SafeChild $GameDir $entry.path
                if ($entry.kind -eq 'added' -and -not (Test-Path -LiteralPath $path)) { continue }
                if ((Get-KnownState $entry $path) -notin @('current','previous','original')) { throw "알 수 없게 바뀐 파일이 있어 복원을 멈췄습니다: $($entry.path)" }
            }
            Restore-OriginalFiles
            Write-Output '복원 통과: 원래 파일로 되돌렸습니다. 저장과 설정은 그대로이고 백업도 남겨 두었습니다.'
            exit 0
        }
        $alreadyInstalled = $true
        foreach ($entry in $manifest.files) {
            $path = Get-SafeChild $GameDir $entry.path
            if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Sha256 $path) -ne $entry.target.sha256) { $alreadyInstalled = $false }
        }
        if ($alreadyInstalled) { Write-Output "이미 설치됨: 이 판($($manifest.version))이 그대로 있습니다."; exit 0 }
        # Each file may be original, this release, or a known earlier release (upgrade).
        $needsBackup = $false
        foreach ($entry in $manifest.files) {
            $state = Get-KnownState $entry (Get-SafeChild $GameDir $entry.path)
            if ($state -eq 'unknown') { throw "이 패치가 모르는 파일입니다. 지원 원본이나 이전 한국어 패치 상태로 되돌린 뒤 다시 실행하세요: $($entry.path)" }
            if ($entry.kind -eq 'delta' -and $state -eq 'missing') { throw "게임 파일이 없습니다: $($entry.path)" }
            if ($entry.kind -eq 'delta' -and $state -ne 'original') { $needsBackup = $true }
        }
        if ($needsBackup -and -not (Test-Path -LiteralPath $backupRoot)) { throw '이전 패치가 깔려 있는데 원본 백업 폴더가 없습니다. 원본 게임 파일로 되돌린 뒤 다시 설치하세요.' }
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
            Write-Json (Get-SafeChild $backupRoot 'ready.json') @{contents='original-files'; created_by=$manifest.version; created_utc=[DateTime]::UtcNow.ToString('o')}
        }
        $stageRoot = Get-SafeChild $backupRoot ('stage-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $stageRoot | Out-Null
        foreach ($entry in $manifest.files) {
            $target = Get-SafeChild $stageRoot $entry.path
            $payload = Get-SafeChild $packageRoot $entry.payload
            if ($entry.kind -eq 'delta') {
                & $patcher (Get-SafeChild $backupRoot $entry.path) $payload $target | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "차분 적용 실패: $($entry.path)" }
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
            try { Restore-OriginalFiles } catch { throw "설치에 실패했고 되돌리기도 중간에 멈췄습니다. 백업 폴더를 지우지 말고 Restore.cmd 를 실행하세요. $($_.Exception.Message)" }
            throw "설치에 실패해 원래 파일로 되돌렸습니다. $($installError.Exception.Message)"
        }
        Write-Output "설치 통과: 한국어 패치 $($manifest.version) 설치와 확인을 마쳤습니다. 저장과 설정은 건드리지 않았습니다."
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
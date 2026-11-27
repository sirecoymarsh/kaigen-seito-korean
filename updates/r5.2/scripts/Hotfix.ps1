#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Install','Verify','Restore')][string]$Action = 'Install',
    [string]$GameDir
)
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$packageRoot = [IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$allNames = @('ko.dll')

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

try {
    if ([string]::IsNullOrWhiteSpace($GameDir)) {
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object Windows.Forms.FolderBrowserDialog
        $dialog.Description = 'r5.1 한국어 패치가 설치된 KaigenSeito.exe 폴더를 선택하세요.'
        if ($dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { exit 2 }
        $GameDir = $dialog.SelectedPath
        $dialog.Dispose()
    }
    $GameDir = Get-CanonicalPath $GameDir
    Assert-NoReparseAncestry $GameDir
    if (-not (Test-Path -LiteralPath $GameDir -PathType Container)) { throw '게임 폴더가 없습니다.' }
    $manifest = Get-Content -LiteralPath (Get-SafeChild $packageRoot 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.schema -ne 'kaigen-seito-r5-hotfix-v1' -or $manifest.requires -ne 'v2026.11.27-r5.1' -or @($manifest.files).Count -ne 1) { throw '지원하지 않는 핫픽스 명세입니다.' }
    $entry = $manifest.files[0]
    if ($entry.path -ne 'ko.dll' -or $entry.payload -ne 'patches/ko.dll.hdiff' -or $entry.source.sha256 -notmatch '^[a-f0-9]{64}$' -or $entry.target.sha256 -notmatch '^[a-f0-9]{64}$') { throw '차분 명세가 잘못되었습니다.' }
    $anchorNames = @('cg.pak','data.pak','KaigenSeito.exe','script.pak','system.dll','system.pak','mpeg.pak','sound.pak')
    if (@($manifest.unchanged).Count -ne 8 -or @($manifest.unchanged.path | Sort-Object -Unique).Count -ne 8) { throw 'r5 확인 파일 목록이 잘못되었습니다.' }
    foreach ($anchor in $manifest.unchanged) {
        if ($anchor.path -notin $anchorNames) { throw 'r5 확인 파일 이름이 잘못되었습니다.' }
        Assert-File (Get-SafeChild $GameDir $anchor.path) $anchor
    }
    $gameDll = Get-SafeChild $GameDir 'ko.dll'
    $hash = Get-Sha256 $gameDll
    if ($hash -ne $entry.source.sha256 -and $hash -ne $entry.target.sha256) { throw 'r5.1 또는 이 핫픽스의 DLL이 아닙니다. 먼저 r5.1 업데이트를 설치하세요.' }
    if ($Action -eq 'Verify') {
        Assert-File $gameDll $entry.target
        Write-Output "검사 통과: $($manifest.version). 저장·설정·영상·대본은 변경하지 않았습니다."
        exit 0
    }
    Assert-GameStopped
    $lockPath = Get-SafeChild $GameDir '.kaigen-ko-install.lock'
    $lock = [IO.File]::Open($lockPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    $stageRoot = $null
    try {
        # Check again after locking, including any known file state changed during preparation.
        $hash = Get-Sha256 $gameDll
        if ($hash -ne $entry.source.sha256 -and $hash -ne $entry.target.sha256) { throw '설치 준비 중 DLL이 바뀌었습니다.' }
        $backupRoot = Get-SafeChild $GameDir '.kaigen-ko-r5.2-backup'
        $backupDll = Get-SafeChild $backupRoot 'ko.dll'
        if ($Action -eq 'Restore') {
            if ($hash -eq $entry.source.sha256) { Write-Output '이미 r5.1 상태입니다.'; exit 0 }
            Assert-File $backupDll $entry.source
            Set-VerifiedFile $backupDll $gameDll $entry.source
            Write-Output '핫픽스 제거 통과: r5.1로 되돌렸습니다. 원본 백업과 저장·설정은 그대로입니다.'
            exit 0
        }
        if ($hash -eq $entry.target.sha256) { Write-Output '이미 이 핫픽스가 설치되어 있습니다.'; exit 0 }
        if ($manifest.patcher.path -ne 'tools/hpatchz.exe') { throw '패치 도구 경로가 잘못되었습니다.' }
        $patcher = Get-SafeChild $packageRoot $manifest.patcher.path
        $patch = Get-SafeChild $packageRoot $entry.payload
        Assert-File $patcher $manifest.patcher
        Assert-File $patch $entry.patch
        if (-not (Test-Path -LiteralPath $backupRoot)) { New-Item -ItemType Directory -Path $backupRoot | Out-Null }
        if (Test-Path -LiteralPath $backupDll) { Assert-File $backupDll $entry.source }
        else { Set-VerifiedFile $gameDll $backupDll $entry.source }
        $stageRoot = Get-SafeChild $backupRoot ('stage-' + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $stageRoot | Out-Null
        $staged = Get-SafeChild $stageRoot 'ko.dll'
        & $patcher $backupDll $patch $staged
        if ($LASTEXITCODE -ne 0) { throw '차분 생성에 실패했습니다. 현재 게임 파일은 바꾸지 않았습니다.' }
        Assert-File $staged $entry.target
        Assert-File $gameDll $entry.source
        try { Set-VerifiedFile $staged $gameDll $entry.target }
        catch {
            $failure = $_
            if ((Get-Sha256 $gameDll) -eq $entry.target.sha256) { Set-VerifiedFile $backupDll $gameDll $entry.source }
            throw $failure
        }
        Write-Output "설치 통과: $($manifest.version). ko.dll만 업데이트했습니다."
    } finally {
        if ($null -ne $stageRoot -and (Test-Path -LiteralPath $stageRoot)) {
            # Delete only this installer's single known staging file, then its empty directory.
            $staged = Get-SafeChild $stageRoot 'ko.dll'
            if (Test-Path -LiteralPath $staged -PathType Leaf) { Remove-Item -LiteralPath $staged -Force }
            if (@(Get-ChildItem -LiteralPath $stageRoot -Force).Count -eq 0) { Remove-Item -LiteralPath $stageRoot }
        }
        $lock.Dispose()
        Remove-Item -LiteralPath $lockPath -Force
    }
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}

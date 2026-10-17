[CmdletBinding()]
param(
    [string]$ArchipelagoPath,
    [string]$BackupRoot,
    [switch]$ValidateOnly,
    [switch]$NoPause
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Install-KhrecomFixedClient {
    $taskSource = Join-Path $PSScriptRoot 'client\khrecom.apworld'
    $taskExpectedHash = '4745B3F906A3DE39183B1A2052D5AF2DC565125FBD3118CB2ADCA1E5551F9EC9'
    if (!(Test-Path -LiteralPath $taskSource -PathType Leaf)) {
        throw 'The bundled client is missing. Extract the entire mod ZIP before running this installer.'
    }
    if ((Get-FileHash -LiteralPath $taskSource -Algorithm SHA256).Hash -ne $taskExpectedHash) {
        throw 'Bundled client checksum failed. Extract a fresh copy of the mod ZIP.'
    }

    $taskInstallRoot = $ArchipelagoPath
    if ([string]::IsNullOrWhiteSpace($taskInstallRoot)) {
        $taskInstallRoot = Join-Path $env:ProgramData 'Archipelago'
        if (!(Test-Path -LiteralPath (Join-Path $taskInstallRoot 'ArchipelagoLauncher.exe') -PathType Leaf)) {
            if ($NoPause) { throw 'Specify -ArchipelagoPath with your Archipelago installation folder.' }
            $taskInstallRoot = (Read-Host 'Enter the folder containing ArchipelagoLauncher.exe').Trim().Trim('"')
        }
    }
    $taskInstallRoot = (Resolve-Path -LiteralPath $taskInstallRoot).Path
    if (!(Test-Path -LiteralPath (Join-Path $taskInstallRoot 'ArchipelagoLauncher.exe') -PathType Leaf)) {
        throw 'This folder does not contain ArchipelagoLauncher.exe. Select your Archipelago installation.'
    }
    $taskWorldDirectory = Join-Path $taskInstallRoot 'custom_worlds'
    $taskTarget = Join-Path $taskWorldDirectory 'khrecom.apworld'
    if ($ValidateOnly) {
        return [pscustomobject]@{Status='Validated'; Target=$taskTarget; Backup=$null}
    }
    if ((Test-Path -LiteralPath $taskTarget -PathType Leaf) -and
        (Get-FileHash -LiteralPath $taskTarget -Algorithm SHA256).Hash -eq $taskExpectedHash) {
        return [pscustomobject]@{Status='AlreadyInstalled'; Target=$taskTarget; Backup=$null}
    }

    $taskBackupPath = $null
    if (Test-Path -LiteralPath $taskTarget -PathType Leaf) {
        $taskBackupRoot = $BackupRoot
        if ([string]::IsNullOrWhiteSpace($taskBackupRoot)) {
            $taskBackupRoot = Join-Path $env:LOCALAPPDATA 'KHRECOM-DeathLink-Fix\backups'
        }
        $taskBackupName = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8)
        $taskBackupPath = Join-Path $taskBackupRoot $taskBackupName
        New-Item -ItemType Directory -Path $taskBackupPath -Force | Out-Null
        $taskBackupFile = Join-Path $taskBackupPath 'khrecom.apworld'
        $taskOriginalHash = (Get-FileHash -LiteralPath $taskTarget -Algorithm SHA256).Hash
        Copy-Item -LiteralPath $taskTarget -Destination $taskBackupFile
        if ((Get-FileHash -LiteralPath $taskBackupFile -Algorithm SHA256).Hash -ne $taskOriginalHash) {
            throw 'Backup verification failed. The installed client was not replaced.'
        }
        [ordered]@{
            originalPath=$taskTarget
            originalSha256=$taskOriginalHash
            installedSha256=$taskExpectedHash
            createdAt=(Get-Date).ToString('o')
        } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskBackupPath 'manifest.json') -Encoding UTF8
    }

    New-Item -ItemType Directory -Path $taskWorldDirectory -Force | Out-Null
    $taskTemporaryFile = Join-Path $taskWorldDirectory ('.khrecom-deathlink-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        Copy-Item -LiteralPath $taskSource -Destination $taskTemporaryFile
        if ((Get-FileHash -LiteralPath $taskTemporaryFile -Algorithm SHA256).Hash -ne $taskExpectedHash) {
            throw 'Copied client checksum failed. The installed client was not replaced.'
        }
        Move-Item -LiteralPath $taskTemporaryFile -Destination $taskTarget -Force
        if ((Get-FileHash -LiteralPath $taskTarget -Algorithm SHA256).Hash -ne $taskExpectedHash) {
            throw 'Installation verification failed. Restore the backup before using this client.'
        }
    }
    finally {
        if (Test-Path -LiteralPath $taskTemporaryFile -PathType Leaf) {
            Remove-Item -LiteralPath $taskTemporaryFile
        }
    }
    return [pscustomobject]@{Status='Installed'; Target=$taskTarget; Backup=$taskBackupPath}
}

try {
    $taskResult = Install-KhrecomFixedClient
    Write-Host ('Client status: ' + $taskResult.Status)
    Write-Host ('Client file: ' + $taskResult.Target)
    if ($taskResult.Backup) { Write-Host ('Original backup: ' + $taskResult.Backup) }
    Write-Host 'Restart the KHRECOM client, reconnect, and enable /deathlink.'
    $taskResult
    if (!$NoPause) { Read-Host 'Press Enter to close' | Out-Null }
}
catch {
    if ($NoPause) { throw }
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host 'Close the KHRECOM client before installing. For access errors, use an authorized administrator session or copy the client manually as described in README.txt.'
    Read-Host 'Press Enter to close' | Out-Null
    exit 1
}

<#
.SYNOPSIS
    Installs Prisma Access Browser and enables Microsoft SSO auto-login.

.DESCRIPTION
    Silent, unattended installer for MDM/RMM deployment. Safe to run on a schedule:
    already-installed devices are a no-op.

    Microsoft SSO auto-login requires a device joined to Microsoft Entra ID. On other
    devices the browser installs normally and the auto-login policy is skipped.

    Must run elevated (as SYSTEM, which RMM agents use by default).

.PARAMETER Force
    Reinstall even if Prisma Access Browser is already present.

.PARAMETER SkipAutoLogin
    Never configure Microsoft SSO auto-login. With -Uninstall, leaves its settings in place.

.PARAMETER ForceAutoLogin
    Configure auto-login even if the device is not detected as Entra-joined.
    Ignored when -SkipAutoLogin is given.

.PARAMETER Uninstall
    Removes Prisma Access Browser and the auto-login settings. -Force is ignored.

.PARAMETER LogPath
    Log file location. Defaults to
    C:\ProgramData\Prisma Access Browser\install-prisma-browser.log

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\install-prisma-browser.ps1

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\install-prisma-browser.ps1 -Uninstall

.NOTES
    Exit codes:
      0   Success. Installed or already present.
      10  Not running elevated.
      11  Unsupported processor architecture.
      20  Could not resolve the installer download location.
      21  Installer download failed.
      22  Installer integrity check failed.
      30  Installation failed.
      31  Uninstallation failed.
      40  Auto-login settings could not be written.
      1   Unexpected error.

    A reboot-required result is reported and treated as success.
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$SkipAutoLogin,
    [switch]$ForceAutoLogin,
    [switch]$Uninstall,
    [string]$LogPath = (Join-Path $env:ProgramData 'Prisma Access Browser\install-prisma-browser.log')
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$ProductName = 'Prisma Access Browser'
$PolicyKey = 'HKLM:\Software\Policies\Palo Alto Networks\PrismaAccessBrowser'
# Injected at serve time from the resolved installer references (ADR-0010): the
# environment (staging beta vs prod stable) picks the app ID and base URL.
$AppId = '%7Bdfef2477-4f0e-454b-bc0d-03ce61074e4c%7D'
$BaseUrl = 'https://releases.talon-sec.com/api/v1/latest'

$script:LogReady = $false

function Write-DeployLog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO'
    )

    $Line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Output $Line

    try {
        if (-not $script:LogReady) {
            $LogDir = Split-Path -Path $LogPath -Parent
            if ($LogDir -and -not (Test-Path $LogDir)) {
                New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
            }
            $script:LogReady = $true
        }
        Add-Content -Path $LogPath -Value $Line -Encoding UTF8
    }
    catch {
        $script:LogReady = $false
    }
}

function Exit-With {
    param([Parameter(Mandatory)][int]$Code, [Parameter(Mandatory)][string]$Message)

    if ($Code -eq 0) { Write-DeployLog $Message } else { Write-DeployLog $Message -Level 'ERROR' }
    exit $Code
}

function Get-InstalledProduct {
    $Paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($Path in $Paths) {
        if (Test-Path $Path) {
            $Found = Get-ItemProperty $Path -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like "*$ProductName*" } |
                Select-Object -First 1
            if ($Found) { return $Found }
        }
    }
    return $null
}

function Test-EntraJoined {
    # Function-scoped: a native command writing to stderr must not become a
    # terminating error under the script's 'Stop' preference.
    $ErrorActionPreference = 'Continue'

    $Exe = Join-Path $env:SystemRoot 'System32\dsregcmd.exe'
    if (-not (Test-Path $Exe)) {
        Write-DeployLog 'Cannot determine the device join state (dsregcmd.exe not present).' -Level 'WARN'
        return $false
    }
    try {
        $Output = & $Exe /status 2>&1 | Out-String
    }
    catch {
        Write-DeployLog "Cannot determine the device join state: $($_.Exception.Message)" -Level 'WARN'
        return $false
    }
    return [bool]($Output -match '(?im)^\s*AzureAdJoined\s*:\s*YES\s*$')
}

function Get-MsiLogPath {
    param([Parameter(Mandatory)][string]$FileName)

    $Dir = Split-Path -Path $LogPath -Parent
    if (-not $Dir) { $Dir = $env:ProgramData }
    return (Join-Path $Dir $FileName)
}

Write-DeployLog "=== $ProductName deployment script started (log: $LogPath) ==="

$Identity = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $Identity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Exit-With 10 'This script must run elevated (as SYSTEM or an administrator).'
}

# PROCESSOR_ARCHITECTURE reports x86 under a 32-bit PowerShell host on 64-bit Windows.
$Arch = $env:PROCESSOR_ARCHITEW6432
if (-not $Arch) { $Arch = $env:PROCESSOR_ARCHITECTURE }

switch ($Arch) {
    'AMD64' { $DownloadArch = 'x64' }
    'ARM64' { $DownloadArch = 'arm64' }
    default { Exit-With 11 "Unsupported processor architecture: $Arch" }
}

try {
    [Net.ServicePointManager]::SecurityProtocol =
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
}
catch {
    Write-DeployLog "Could not raise the TLS protocol level: $($_.Exception.Message)" -Level 'WARN'
}

# --- uninstall ---------------------------------------------------------------
if ($Uninstall) {
    $Existing = Get-InstalledProduct

    if (-not $SkipAutoLogin) {
        try {
            if (Test-Path $PolicyKey) {
                foreach ($Name in @('ForceEnableMsSSO', 'ForceEnableMsSSOAutoLogin')) {
                    Remove-ItemProperty -Path $PolicyKey -Name $Name -Force -ErrorAction SilentlyContinue
                }
                # Remove the key only if empty; other policies may legitimately live here.
                $Key = Get-Item -Path $PolicyKey
                if ($Key.ValueCount -eq 0 -and $Key.SubKeyCount -eq 0) {
                    Remove-Item -Path $PolicyKey -Force
                }
                Write-DeployLog 'Microsoft SSO auto-login settings removed.'
            }
        }
        catch {
            Write-DeployLog "Could not fully remove the auto-login settings: $($_.Exception.Message)" -Level 'WARN'
        }
    }

    if (-not $Existing) {
        Exit-With 0 "$ProductName is not installed; nothing to uninstall."
    }

    $GuidPattern = '\{[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}\}'
    $ProductCode = $Existing.PSChildName
    if ($ProductCode -notmatch "^$GuidPattern$") {
        $Found = [regex]::Match([string]$Existing.UninstallString, $GuidPattern)
        if (-not $Found.Success) {
            Exit-With 31 "Could not determine the product code for $ProductName."
        }
        $ProductCode = $Found.Value
    }

    Write-DeployLog "Uninstalling $ProductName $($Existing.DisplayVersion)..."
    $UninstallLog = Get-MsiLogPath 'msiexec-uninstall.log'
    $Process = Start-Process -FilePath 'msiexec.exe' `
        -ArgumentList @('/x', $ProductCode, '/qn', '/norestart', '/l*v', "`"$UninstallLog`"") `
        -Wait -PassThru
    $MsiCode = $Process.ExitCode

    if ($MsiCode -eq 0) {
        Exit-With 0 "$ProductName uninstalled successfully."
    }
    if ($MsiCode -eq 3010 -or $MsiCode -eq 1641) {
        Exit-With 0 "$ProductName uninstalled. A reboot is required to complete removal."
    }
    Write-DeployLog "Details: $UninstallLog" -Level 'ERROR'
    Exit-With 31 "Uninstallation failed with exit code $MsiCode."
}

# --- auto-login settings -----------------------------------------------------
# Applied before the install check so existing installations are also covered.
if ($SkipAutoLogin) {
    Write-DeployLog 'Skipping Microsoft SSO auto-login (-SkipAutoLogin).'
}
else {
    $ApplyPolicy = $true
    if ($ForceAutoLogin) {
        Write-DeployLog 'Configuring Microsoft SSO auto-login without detection (-ForceAutoLogin).'
    }
    elseif (-not (Test-EntraJoined)) {
        $ApplyPolicy = $false
        Write-DeployLog ('Device is not joined to Microsoft Entra ID; skipping auto-login. The ' +
            'browser install is unaffected. Use -ForceAutoLogin to override.')
    }

    if ($ApplyPolicy) {
        try {
            # Test-Path guard: on the registry provider, New-Item -Force recreates an
            # existing key and discards its values.
            if (-not (Test-Path $PolicyKey)) {
                New-Item -Path $PolicyKey -Force | Out-Null
            }
            Set-ItemProperty -Path $PolicyKey -Name 'ForceEnableMsSSO' -Value 1 -Type DWord
            Set-ItemProperty -Path $PolicyKey -Name 'ForceEnableMsSSOAutoLogin' -Value 1 -Type DWord
            Write-DeployLog 'Microsoft SSO auto-login configured.'
        }
        catch {
            Exit-With 40 "Failed to configure auto-login: $($_.Exception.Message)"
        }
    }
}

# --- install -----------------------------------------------------------------
$Existing = Get-InstalledProduct

if ($Existing -and -not $Force) {
    Exit-With 0 "$ProductName $($Existing.DisplayVersion) is already installed. Use -Force to reinstall."
}
if ($Existing) {
    Write-DeployLog "$ProductName $($Existing.DisplayVersion) is installed. Reinstalling (-Force)."
}

$TempDir = Join-Path $env:TEMP ('prisma-browser-install-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
$MsiPath = Join-Path $TempDir 'PrismaAccessBrowser.msi'

try {
    Write-DeployLog 'Resolving the installer location...'
    $DownloadUrl = $null
    try {
        $ApiUrl = "${BaseUrl}?appid=${AppId}&platform=win&architecture=${DownloadArch}&channel=packaged"
        $Response = (Invoke-WebRequest -Uri $ApiUrl -UseBasicParsing).Content
        # The response carries a leading XSSI guard that ConvertFrom-Json rejects.
        $Update = ($Response -replace "^\)\]\}'", '' | ConvertFrom-Json).response.apps[0].updatecheck
        $Operation = $Update.pipelines.operations |
            Where-Object { $_.type -eq 'download' -and $_.urls } |
            Select-Object -First 1
        # Guarded: indexing a null operation would throw and mask the real cause.
        if ($Operation) { $DownloadUrl = $Operation.urls[0].url }
    }
    catch {
        Exit-With 20 "Could not reach the download service: $($_.Exception.Message)"
    }

    if (-not $DownloadUrl) {
        Exit-With 20 'The download service returned no installer location.'
    }

    Write-DeployLog "Downloading $ProductName $($Update.nextversion) ($DownloadArch)..."
    try {
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $MsiPath -UseBasicParsing
    }
    catch {
        Exit-With 21 "Download failed: $($_.Exception.Message)"
    }

    $ExpectedHash = $Operation.out.sha256
    if ($ExpectedHash) {
        $ActualHash = (Get-FileHash -Path $MsiPath -Algorithm SHA256).Hash
        if ($ActualHash -ne $ExpectedHash) {
            Exit-With 22 'Installer integrity check failed; the download was discarded.'
        }
        Write-DeployLog 'Installer verified.'
    }

    Write-DeployLog "Installing $ProductName $($Update.nextversion)..."
    $MsiLog = Get-MsiLogPath 'msiexec.log'
    $Process = Start-Process -FilePath 'msiexec.exe' `
        -ArgumentList @('/i', "`"$MsiPath`"", '/qn', 'ALLUSERS=1', '/norestart', '/l*v', "`"$MsiLog`"") `
        -Wait -PassThru
    $MsiCode = $Process.ExitCode

    if ($MsiCode -eq 0) {
        Exit-With 0 "$ProductName $($Update.nextversion) installed successfully."
    }
    if ($MsiCode -eq 3010 -or $MsiCode -eq 1641) {
        Exit-With 0 "$ProductName $($Update.nextversion) installed. A reboot is required to complete setup."
    }
    Write-DeployLog "Details: $MsiLog" -Level 'ERROR'
    Exit-With 30 "Installation failed with exit code $MsiCode."
}
catch {
    Exit-With 1 "Unexpected error: $($_.Exception.Message)"
}
finally {
    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

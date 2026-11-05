function Set-Windows11Tweaks {

    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Administrator privileges are required."
    }

    function Set-RegistryValue {
        param(
            [Parameter(Mandatory)] [string]$Path,
            [Parameter(Mandatory)] [string]$Name,
            [Parameter(Mandatory)] [object]$Value,
            [ValidateSet('String', 'ExpandString', 'Binary', 'DWord', 'MultiString', 'QWord')]
            [string]$Type = 'DWord'
        )

        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }

        try {
            New-ItemProperty `
                -Path $Path `
                -Name $Name `
                -Value $Value `
                -PropertyType $Type `
                -Force `
                -ErrorAction Stop | Out-Null
        }
        catch {
            throw $_
        }
    }

    $RegistrySettings = @(
        [PSCustomObject]@{ Description = 'Disable Start Menu Web Search'; RegPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; RegName = 'DisableSearchBoxSuggestions'; RegValue = 1; RegType = 'DWord' }
        [PSCustomObject]@{ Description = 'Hide Windows Store and Web Search Results from Start Menu'; RegPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'; RegName = 'BingSearchEnabled'; RegValue = 0; RegType = 'DWord' }

        [PSCustomObject]@{ Description = 'Enable Updates for Other Microsoft Products'; RegPath = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'; RegName = 'AllowMUUpdateService'; RegValue = 1; RegType = 'DWord' }

        [PSCustomObject]@{ Description = 'Hide New Outlook Toggle'; RegPath = 'HKLM:\SOFTWARE\Microsoft\Office\16.0\Outlook\Options\General'; RegName = 'HideNewOutlookToggle'; RegValue = 1; RegType = 'DWord' }

        [PSCustomObject]@{ Description = 'Disable Advertising Info'; RegPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'; RegName = 'DisabledByGroupPolicy'; RegValue = 1; RegType = 'DWord' }
        [PSCustomObject]@{ Description = 'Disable Windows 11 Privacy Experience'; RegPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE'; RegName = 'DisablePrivacyExperience'; RegValue = 1; RegType = 'DWord' }

        [PSCustomObject]@{ Description = 'Disable Widgets (News and Interests)'; RegPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'; RegName = 'AllowNewsAndInterests'; RegValue = 0; RegType = 'DWord' }
        [PSCustomObject]@{ Description = 'Disable Windows Ink Workspace'; RegPath = 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace'; RegName = 'AllowWindowsInkWorkspace'; RegValue = 0; RegType = 'DWord' }

        [PSCustomObject]@{ Description = 'Disable Windows Backup Notifications'; RegPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsBackup'; RegName = 'DisableMonitoring'; RegValue = 1; RegType = 'DWord' }

        [PSCustomObject]@{ Description = 'Enable Storage Sense'; RegPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense'; RegName = 'AllowStorageSenseGlobal'; RegValue = 1; RegType = 'DWord' }
        [PSCustomObject]@{ Description = 'Run Storage Sense Daily'; RegPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense'; RegName = 'ConfigStorageSenseGlobalCadence'; RegValue = 1; RegType = 'DWord' }
        [PSCustomObject]@{ Description = 'Clean Temporary Files'; RegPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense'; RegName = 'AllowStorageSenseTemporaryFilesCleanup'; RegValue = 1; RegType = 'DWord' }
        [PSCustomObject]@{ Description = 'Clean Cloud Content Older Than 7 Days'; RegPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense'; RegName = 'ConfigStorageSenseCloudContentDehydrationThreshold'; RegValue = 7; RegType = 'DWord' }
        [PSCustomObject]@{ Description = 'Clean Downloads Older Than 30 Days'; RegPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense'; RegName = 'ConfigStorageSenseDownloadsCleanupThreshold'; RegValue = 30; RegType = 'DWord' }
        [PSCustomObject]@{ Description = 'Clean Recycle Bin Files Older Than 14 Days'; RegPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense'; RegName = 'ConfigStorageSenseRecycleBinCleanupThreshold'; RegValue = 14; RegType = 'DWord' }

        [PSCustomObject]@{ Description = 'Hide Edge First-Run Experience'; RegPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'; RegName = 'HideFirstRunExperience'; RegValue = 1; RegType = 'DWord' }
    )

    $Failed = [System.Collections.Generic.List[object]]::new()
    $AppliedCount = 0

    Write-Host ""
    Write-Host "Applying Windows 11 Registry Tweaks..." -ForegroundColor Yellow
    Write-Host ""

    foreach ($Setting in $RegistrySettings) {

        Write-Host "[RUNNING] $($Setting.Description)" -ForegroundColor Yellow

        try {
            Set-RegistryValue `
                -Path $Setting.RegPath `
                -Name $Setting.RegName `
                -Value $Setting.RegValue `
                -Type $Setting.RegType

            $AppliedCount++

            Write-Host "[PASS] $($Setting.Description)" -ForegroundColor Green
        }
        catch {
            Write-Host "[FAIL] $($Setting.Description)" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor DarkRed

            $Failed.Add([PSCustomObject]@{
                Description = $Setting.Description
                RegPath     = $Setting.RegPath
                RegName     = $Setting.RegName
                Error       = $_.Exception.Message
            })
        }
    }

    Write-Host ""

    if ($Failed.Count -gt 0) {

        Write-Host "==================================================" -ForegroundColor Red
        Write-Host " WINDOWS 11 TWEAKS COMPLETED WITH FAILURES " -ForegroundColor Red
        Write-Host "==================================================" -ForegroundColor Red
        Write-Host ""

        $Failed | Format-Table Description, RegName, Error -AutoSize

        return [PSCustomObject]@{
            Success   = $false
            Applied   = $AppliedCount
            Failed    = $Failed.Count
            Failures  = $Failed
            Timestamp = Get-Date
        }
    }

    Write-Host "==================================================" -ForegroundColor Green
    Write-Host " WINDOWS 11 TWEAKS COMPLETED SUCCESSFULLY " -ForegroundColor Green
    Write-Host "==================================================" -ForegroundColor Green

    return [PSCustomObject]@{
        Success   = $true
        Applied   = $AppliedCount
        Failed    = 0
        Timestamp = Get-Date
    }
}

function Set-Windows11Tweaks {

    Write-Host "Applying Windows 11 Registry Tweaks..." -ForegroundColor Yellow

    $RegistrySettings = @(

        ###
        ### Start Menu & Search
        ###
        [PSCustomObject]@{ Description = "Disable Start Menu Web Search"; RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"; RegName = "DisableSearchBoxSuggestions"; RegValue = 1; RegType = "DWord" }
        [PSCustomObject]@{ Description = "Hide Windows Store and Web Search Results from Start Menu"; RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search"; RegName = "BingSearchEnabled"; RegValue = 0; RegType = "DWord" }

        ###
        ### Windows Update
        ###
        [PSCustomObject]@{ Description = "Enable Updates for Other Microsoft Products"; RegPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"; RegName = "AllowMUUpdateService"; RegValue = 1; RegType = "DWord" }

        ###
        ### Microsoft Outlook
        ###
        [PSCustomObject]@{ Description = "Hide New Outlook Toggle"; RegPath = "HKLM:\SOFTWARE\Microsoft\Office\16.0\Outlook\Options\General"; RegName = "HideNewOutlookToggle"; RegValue = 1; RegType = "DWord" }

        ###
        ### Privacy & Advertising
        ###
        [PSCustomObject]@{ Description = "Disable Advertising Info"; RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"; RegName = "DisabledByGroupPolicy"; RegValue = 1; RegType = "DWord" }
        [PSCustomObject]@{ Description = "Disable Windows 11 Privacy Experience"; RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE"; RegName = "DisablePrivacyExperience"; RegValue = 1; RegType = "DWord" }

        ###
        ### Widgets & Windows Ink
        ###
        [PSCustomObject]@{ Description = "Disable Widgets (News and Interests)"; RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"; RegName = "AllowNewsAndInterests"; RegValue = 0; RegType = "DWord" }
        [PSCustomObject]@{ Description = "Disable Windows Ink Workspace"; RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace"; RegName = "AllowWindowsInkWorkspace"; RegValue = 0; RegType = "DWord" }

        ###
        ### Windows Backup
        ###
        [PSCustomObject]@{ Description = "Disable Windows Backup Notifications"; RegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsBackup"; RegName = "DisableMonitoring"; RegValue = 1; RegType = "DWord" }

        ###
        ### Storage Sense
        ###
        [PSCustomObject]@{ Description = "Enable Storage Sense"; RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense"; RegName = "AllowStorageSenseGlobal"; RegValue = 1; RegType = "DWord" }
        [PSCustomObject]@{ Description = "Run Storage Sense Daily"; RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense"; RegName = "ConfigStorageSenseGlobalCadence"; RegValue = 1; RegType = "DWord" }
        [PSCustomObject]@{ Description = "Clean Temporary Files"; RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense"; RegName = "AllowStorageSenseTemporaryFilesCleanup"; RegValue = 1; RegType = "DWord" }
        [PSCustomObject]@{ Description = "Clean Cloud Content Older Than 7 Days"; RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense"; RegName = "ConfigStorageSenseCloudContentDehydrationThreshold"; RegValue = 7; RegType = "DWord" }
        [PSCustomObject]@{ Description = "Clean Downloads Older Than 30 Days"; RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense"; RegName = "ConfigStorageSenseDownloadsCleanupThreshold"; RegValue = 30; RegType = "DWord" }
        [PSCustomObject]@{ Description = "Clean Recycle Bin Files Older Than 14 Days"; RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense"; RegName = "ConfigStorageSenseRecycleBinCleanupThreshold"; RegValue = 14; RegType = "DWord" }

        ###
        ### Microsoft Edge
        ###
        [PSCustomObject]@{ Description = "Hide Edge First-Run Experience"; RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"; RegName = "HideFirstRunExperience"; RegValue = 1; RegType = "DWord" }
    )

    foreach ($Setting in $RegistrySettings) {

        Write-Host "Applying: $($Setting.Description)" -ForegroundColor Cyan

        PCBuild-UpdateRegistry `
            -RegPath $Setting.RegPath `
            -RegName $Setting.RegName `
            -RegValue $Setting.RegValue `
            -RegType $Setting.RegType
    }

    Write-Host ""
    Write-Host "Windows 11 Registry Tweaks Complete." -ForegroundColor Green
}

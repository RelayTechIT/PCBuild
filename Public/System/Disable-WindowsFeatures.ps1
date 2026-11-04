function Disable-WindowsFeatures {
    [CmdletBinding()]
    param()

    try {
         # Disable Recall
        Disable-WindowsOptionalFeature -Online -FeatureName 'Recall' -NoRestart -ErrorAction Stop | Out-Null
        # Disable Remote Desktop Client
        Disable-WindowsOptionalFeature -Online -FeatureName 'Microsoft-RemoteDesktopConnection' -NoRestart -ErrorAction Stop | Out-Null

        Write-Host '[PC Build Menu] PASS - Windows features disabled.'
        return $true
    }
    catch {
        Write-Host "[PC Build Menu] FAIL - $($_.Exception.Message)"
        return $false
    }
}

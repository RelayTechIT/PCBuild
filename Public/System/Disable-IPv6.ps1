function Disable-IPv6 {
    try {
        Write-Host "Disabling IPv6..." -ForegroundColor Cyan
        Disable-NetAdapterBinding -Name "*" -ComponentID ms_tcpip6 -ErrorAction Stop
        Write-Host "IPv6 disabled successfully." -ForegroundColor Green
        return $true

    }
    catch {
        Write-Host "Failed to disable IPv6." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
}

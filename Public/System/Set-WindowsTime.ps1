function Set-WindowsTime {
    try {
        Write-Host "Configuring Windows Time..." -ForegroundColor Cyan
        Set-TimeZone -Id "Eastern Standard Time"
        Stop-Service w32time -Force
        w32tm /config `
            /manualpeerlist:"time.google.com,time.cloudflare.com,time.windows.com" `
            /syncfromflags:manual `
            /reliable:no `
            /update | Out-Null

        Start-Service w32time
        w32tm /resync /force | Out-Null
        Write-Host "Windows Time configured successfully." -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
}

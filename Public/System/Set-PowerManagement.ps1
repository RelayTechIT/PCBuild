function Set-PowerManagement {

    try {

        Write-Host ""
        Write-Host "====================================" -ForegroundColor DarkCyan
        Write-Host "      Configuring Power Settings" -ForegroundColor Cyan
        Write-Host "====================================" -ForegroundColor DarkCyan
        Write-Host ""

        $Steps = @(
            @{ Name = "Monitor Timeout (Plugged In)"; Command = "/change monitor-timeout-ac 30" }
            @{ Name = "Monitor Timeout (Battery)"; Command = "/change monitor-timeout-dc 3" }
            @{ Name = "Hard Drive Timeout (Plugged In)"; Command = "/change disk-timeout-ac 30" }
            @{ Name = "Hard Drive Timeout (Battery)"; Command = "/change disk-timeout-dc 5" }
            @{ Name = "Sleep Timeout (Plugged In)"; Command = "/change standby-timeout-ac 0" }
            @{ Name = "Sleep Timeout (Battery)"; Command = "/change standby-timeout-dc 5" }
            @{ Name = "Hibernate Timeout (Plugged In)"; Command = "/change hibernate-timeout-ac 0" }
            @{ Name = "Hibernate Timeout (Battery)"; Command = "/change hibernate-timeout-dc 0" }
            @{ Name = "Disable Hibernation"; Command = "-h off" }
            @{ Name = "Enable Wake Timers (Plugged In)"; Command = "/SETACVALUEINDEX SCHEME_CURRENT 238c9fa8-0aad-41ed-83f4-97be242c8f20 bd3b718a-0680-4d9d-8ab2-e1d2b4ac806d 1" }
            @{ Name = "Enable Wake Timers (Battery)"; Command = "/SETDCVALUEINDEX SCHEME_CURRENT 238c9fa8-0aad-41ed-83f4-97be242c8f20 bd3b718a-0680-4d9d-8ab2-e1d2b4ac806d 1" }
            @{ Name = "Lid Close Action (Plugged In)"; Command = "/SETACVALUEINDEX SCHEME_CURRENT SUB_BUTTONS LIDACTION 0" }
            @{ Name = "Lid Close Action (Battery)"; Command = "/SETDCVALUEINDEX SCHEME_CURRENT SUB_BUTTONS LIDACTION 1" }
            @{ Name = "Apply Power Plan"; Command = "/SETACTIVE SCHEME_CURRENT" }
        )

        foreach ($Step in $Steps) {

            & powercfg.exe $Step.Command.Split(' ')

            if ($LASTEXITCODE -ne 0) {
                throw $Step.Name
            }

            Write-Host ("[✓] {0}" -f $Step.Name) -ForegroundColor Green
        }

        Write-Host ""
        Write-Host "[✓] Power Management Configuration Complete" -ForegroundColor Green
        Write-Host ""

        return $true
    }
    catch {

        Write-Host ""
        Write-Host ("[X] Failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
        Write-Host ""

        return $false
    }
}

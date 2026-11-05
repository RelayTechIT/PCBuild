function Install-SentinelOne {

    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    $ApiKey = $env:PCBUILD_S1_API_KEY
    $SiteToken = $env:PCBUILD_S1_SITE_TOKEN

    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        throw 'PCBUILD_S1_API_KEY is not configured.'
    }

    if ([string]::IsNullOrWhiteSpace($SiteToken)) {
        throw 'PCBUILD_S1_SITE_TOKEN is not configured.'
    }

    if (Get-Package -Name '*Sentinel*' -ErrorAction SilentlyContinue) {
        Write-Host 'SentinelOne already installed.'
        return
    }

    $InstallRoot = 'C:\RTSupport\SentinelOne'
    New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null

    switch ((Get-CimInstance Win32_OperatingSystem).OSArchitecture) {

        '64-bit' {
            $InstallerName = 'SentinelOneInstaller.exe'
            $GatewayUrl = 'https://device-agent.app.us.guardz.com/api/device/agent-gateway/endpoint/installer/sentinel-one/2274068839163744109'
        }

        'ARM 64-bit Processor' {
            $InstallerName = 'SentinelOneInstaller-ARM64.exe'
            $GatewayUrl = 'https://device-agent.app.us.guardz.com/api/device/agent-gateway/endpointl-one/2274068111619771263'
        }

        default {
            throw 'Unsupported architecture.'
        }
    }

    $InstallerPath = Join-Path $InstallRoot $InstallerName

    Write-Host 'Retrieving SentinelOne installer URL...'

    $Headers = @{
        Authorization = "Bearer $ApiKey"
    }

    $SignedUrl = Invoke-RestMethod `
        -Uri $GatewayUrl `
        -Headers $Headers `
        -Method Get

    Write-Host 'Downloading SentinelOne...'

    Invoke-WebRequest `
        -Uri $SignedUrl `
        -OutFile $InstallerPath `
        -UseBasicParsing

    $Process = Start-Process `
        -FilePath $InstallerPath `
        -ArgumentList "-t $SiteToken -q" `
        -Wait `
        -PassThru

    if ($Process.ExitCode -ne 0) {
        throw "SentinelOne installer returned exit code $($Process.ExitCode)."
    }

    Write-Host 'SentinelOne installed successfully.'
}

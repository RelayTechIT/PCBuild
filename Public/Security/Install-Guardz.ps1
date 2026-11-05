function Install-Guardz {

    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    $OrgKey = $env:PCBUILD_GUARDZ_KEY

    if ([string]::IsNullOrWhiteSpace($OrgKey)) {
        throw 'PCBUILD_GUARDZ_KEY is not configured.'
    }

    $InstallRoot = 'C:\RTSupport\GuardzAgent'
    $InstallerPath = Join-Path $InstallRoot 'GuardzAgent.msi'
    $StateFile = "$env:ProgramData\com.guardz\auth-state.json"

    if (Get-Package -Name '*Guardz*' -ErrorAction SilentlyContinue) {
        Write-Host 'Guardz already installed.'
        return
    }

    New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path $StateFile) -Force | Out-Null

    $DownloadUrl = 'https://app.us.guardz.com/api/device-agent/download/windows'

    Write-Host 'Downloading Guardz Agent...'

    Invoke-WebRequest `
        -Uri $DownloadUrl `
        -OutFile $InstallerPath `
        -UseBasicParsing

    @{ organization_key = $OrgKey } |
        ConvertTo-Json -Compress |
        Set-Content $StateFile -Encoding UTF8

    $Process = Start-Process `
        -FilePath 'msiexec.exe' `
        -ArgumentList "/i `"$InstallerPath`" /qn" `
        -Wait `
        -PassThru

    if ($Process.ExitCode -ne 0) {
        throw "Guardz installer returned exit code $($Process.ExitCode)."
    }

    Write-Host 'Guardz installed successfully.'
}

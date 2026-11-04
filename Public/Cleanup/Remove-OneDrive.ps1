function Remove-OneDrive {

    Write-Host "Removing Microsoft OneDrive..." -ForegroundColor Yellow

    # Stop OneDrive if running
    Get-Process OneDrive -ErrorAction SilentlyContinue | Stop-Process -Force

    # Uninstall OneDrive
    $SetupPaths = @(
        "$env:SystemRoot\System32\OneDriveSetup.exe",
        "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
    )

    foreach ($Path in $SetupPaths) {
        if (Test-Path $Path) {
            Start-Process $Path "/uninstall" -Wait -NoNewWindow
        }
    }

    Start-Sleep -Seconds 5

    # Remove leftovers
    $Folders = @(
        "$env:UserProfile\OneDrive",
        "$env:LocalAppData\Microsoft\OneDrive",
        "$env:ProgramData\Microsoft OneDrive",
        "$env:SystemDrive\OneDriveTemp"
    )

    foreach ($Folder in $Folders) {
        if (Test-Path $Folder) {
            Remove-Item $Folder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host "OneDrive removal complete." -ForegroundColor Green
}

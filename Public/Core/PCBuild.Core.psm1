# Configuration
$script:ManifestUri = 'https://raw.githubusercontent.com/RelayTechIT/PCBuild/main/Public/manifest.json'
$script:EnableLogging = $true
$script:LogFile = Join-Path $env:TEMP 'PCBuild.log'

$script:CachedItems = $null
$script:FunctionStatus = @{}
$script:PCBuildConfig = $null

# Logging
function Write-PCBuildLog {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    if (-not $script:EnableLogging) { return }

    $entry = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message

    $color = switch ($Level) {
        'WARN' { 'Yellow' }
        'ERROR' { 'Red' }
        default { 'DarkGray' }
    }

    Write-Host $entry -ForegroundColor $color
    Add-Content -Path $script:LogFile -Value $entry -ErrorAction SilentlyContinue
}

# Configuration Management
function Initialize-PCBuild {
    param([Parameter(Mandatory)][object]$Config)

    $script:PCBuildConfig = $Config

    Write-PCBuildLog 'PC Build configuration initialized.'
}

# Configuration Retrieval
function Get-PCBuildConfig {
    $script:PCBuildConfig
}

# Menu Item Discovery
function Get-GitHubItems {

    if ($script:CachedItems) {
        Write-PCBuildLog 'Using cached manifest.'
        return $script:CachedItems
    }

    try {

        Write-PCBuildLog 'Downloading manifest.'
        Write-PCBuildLog "Manifest URI: $script:ManifestUri"
        Write-PCBuildLog "TenantId: $($script.TenantId)"

        $script:CachedItems = Invoke-RestMethod -Uri $script:ManifestUri -ErrorAction Stop

        Write-PCBuildLog "Loaded $($script:CachedItems.Count) menu items."

        return $script:CachedItems
    }
    catch {

        Write-PCBuildLog $_.Exception.Message ERROR

        throw "Failed to load manifest.json. $($_.Exception.Message)"
    }
}

# Script Execution
function Invoke-GitHubScript {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$FunctionName
    )

    try {

        Write-PCBuildLog "Downloading script: $FunctionName"
        Write-PCBuildLog "URL: $Url"

        $code = (Invoke-WebRequest -Uri $Url -UseBasicParsing -ErrorAction Stop).Content

        Write-PCBuildLog "Downloaded $($code.Length) characters."

        . ([ScriptBlock]::Create($code))

        $command = Get-Command $FunctionName -ErrorAction SilentlyContinue

        if (-not $command) {
            throw "Function '$FunctionName' was not loaded."
        }

        Write-PCBuildLog "Executing function: $FunctionName"

        & $command.Name

        Write-PCBuildLog "Execution completed: $FunctionName"
    }
    catch {

        Write-PCBuildLog $_.Exception.Message ERROR

        throw
    }
}

# Menu Rendering
function Show-PCBuildHeader {
    param(
        [string]$Title,
        [string]$Color = 'Green'
    )

    Write-Host ('=' * 50) -ForegroundColor DarkGreen
    Write-Host $Title -ForegroundColor $Color
    Write-Host ('=' * 50) -ForegroundColor DarkGreen
    Write-Host
}

# Menu Display
function Show-PCBuildMenu {

    do {

        Clear-Host

        $config = Get-PCBuildConfig

        if ($config?.ClientId) {
            Write-PCBuildLog "Oh Dear"
            Write-PCBuildLog "Client Id: $($config.ClientId)"
        }

        Show-PCBuildHeader -Title 'PC BUILD MENU'

        try {
            $items = Get-GitHubItems
        }
        catch {

            Write-Host $_.Exception.Message -ForegroundColor Red
            return
        }

        $lookup = @{}
        $index = 1

        foreach ($category in ($items.Category | Sort-Object -Unique)) {

            $categoryItems = $items |
                Where-Object Category -eq $category |
                Sort-Object Name

            if (-not $categoryItems) { continue }

            Write-Host $category.ToUpper() -ForegroundColor Cyan
            Write-Host ('-' * $category.Length)

            foreach ($item in $categoryItems) {

                $color = switch ($script:FunctionStatus[$item.Name]) {
                    'Success' { 'Green' }
                    'Failed' { 'Red' }
                    default { 'White' }
                }

                Write-Host " [$index] " -ForegroundColor Yellow -NoNewline
                Write-Host $item.Name -ForegroundColor $color

                $lookup[$index] = $item
                $index++
            }

            Write-Host
        }

        Write-Host ' [0] Exit' -ForegroundColor Red
        Write-Host

        $selection = Read-Host 'Selection'

        if ($selection -eq '0') { break }
        if ($selection -notmatch '^\d+$') { continue }

        $selection = [int]$selection

        if (-not $lookup.ContainsKey($selection)) { continue }

        $item = $lookup[$selection]

        Clear-Host

        Write-Host ('=' * 50) -ForegroundColor DarkCyan
        Write-Host "Running: $($item.Name)" -ForegroundColor Cyan
        Write-Host ('=' * 50) -ForegroundColor DarkCyan
        Write-Host

        try {

            Invoke-GitHubScript -Url $item.Url -FunctionName $item.Name

            $script:FunctionStatus[$item.Name] = 'Success'

            Write-PCBuildLog "Success: $($item.Name)"

            Write-Host
            Write-Host "[SUCCESS] $($item.Name)" -ForegroundColor Green
        }
        catch {

            $script:FunctionStatus[$item.Name] = 'Failed'

            Write-PCBuildLog "Failure: $($item.Name)" ERROR
            Write-PCBuildLog $_.Exception.ToString() ERROR

            Write-Host
            Write-Host "[FAILED] $($item.Name)" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Yellow
        }

        Read-Host "`nPress Enter"
    }
    while ($true)
}

# Module Exports
if ($MyInvocation.MyCommand.Module) {
Export-ModuleMember -Function @(
    'Get-GitHubItems',
    'Invoke-GitHubScript',
    'Initialize-PCBuild',
    'Get-PCBuildConfig',
    'Show-PCBuildMenu'
)
}

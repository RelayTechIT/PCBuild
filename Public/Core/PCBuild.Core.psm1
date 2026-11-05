# Configuration
$script:ManifestUri = 'https://raw.githubusercontent.com/RelayTechIT/PCBuild/main/Public/manifest.json'
$script:EnableLogging = $true
$script:LogFile = Join-Path $env:TEMP 'PCBuild.log'

$script:FunctionStatus = @{}
$script:CachedItems = $null

# Logging
function Write-PCBuildLog {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR')]
        [string]$Level = 'INFO'
    )

    if (-not $script:EnableLogging) { return }

    $Entry = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message

    Write-Host $Entry -ForegroundColor @{
        INFO  = 'DarkGray'
        WARN  = 'Yellow'
        ERROR = 'Red'
    }[$Level]

    Add-Content -Path $script:LogFile -Value $Entry -ErrorAction SilentlyContinue
}

# Menu Item Discovery
function Get-GitHubItems {

    if ($script:CachedItems) {
        Write-PCBuildLog "Using cached manifest."
        return $script:CachedItems
    }

    try {

        Write-PCBuildLog "Downloading manifest."
        Write-PCBuildLog "Manifest URI: $script:ManifestUri"
   

        $script:CachedItems = Invoke-RestMethod `
            -Uri $script:ManifestUri `
            -ErrorAction Stop

        Write-PCBuildLog "Loaded $($script:CachedItems.Count) menu items."

        return $script:CachedItems
    }
    catch {

        Write-PCBuildLog $_.Exception.Message 'ERROR'

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

        $Code = (Invoke-WebRequest `
            -Uri $Url `
            -UseBasicParsing `
            -ErrorAction Stop).Content

        Write-PCBuildLog "Downloaded $($Code.Length) characters."

        . ([ScriptBlock]::Create($Code))

        if (-not (Get-Command $FunctionName -ErrorAction SilentlyContinue)) {
            throw "Function '$FunctionName' was not loaded."
        }

        Write-PCBuildLog "Executing function: $FunctionName"

        & $FunctionName

        Write-PCBuildLog "Execution completed: $FunctionName"
    }
    catch {

        Write-PCBuildLog $_.Exception.Message 'ERROR'

        throw
    }
}

# Menu Display
function Show-PCBuildMenu {

    do {

        Clear-Host
        Write-PCBuildLog "Client Id: $script:ClientId"
        Write-Host ('=' * 50) -ForegroundColor DarkGreen
        Write-Host 'PC BUILD MENU' -ForegroundColor Green
        Write-Host ('=' * 50) -ForegroundColor DarkGreen
        Write-Host ''

        try {
            $Items = Get-GitHubItems
        }
        catch {
            Write-Host $_.Exception.Message -ForegroundColor Red
            return
        }

        $Lookup = @{}
        $Index = 1

        foreach ($Category in ($Items.Category | Sort-Object -Unique)) {

            $CategoryItems = $Items |
                Where-Object Category -eq $Category |
                Sort-Object Name

            if (-not $CategoryItems) { continue }

            Write-Host $Category.ToUpper() -ForegroundColor Cyan
            Write-Host ('-' * $Category.Length)

            foreach ($Item in $CategoryItems) {

                $Color = switch ($script:FunctionStatus[$Item.Name]) {
                    'Success' { 'Green' }
                    'Failed' { 'Red' }
                    default   { 'White' }
                }

                Write-Host " [$Index] " -ForegroundColor Yellow -NoNewline
                Write-Host $Item.Name -ForegroundColor $Color

                $Lookup[$Index] = $Item
                $Index++
            }

            Write-Host ''
        }

        Write-Host ' [0] Exit' -ForegroundColor Red
        Write-Host ''

        $Choice = Read-Host 'Selection'

        if ($Choice -eq '0') { break }
        if ($Choice -notmatch '^\d+$') { continue }

        $Choice = [int]$Choice

        if (-not $Lookup.ContainsKey($Choice)) { continue }

        $Item = $Lookup[$Choice]

        Clear-Host

        Write-Host ('=' * 50) -ForegroundColor DarkCyan
        Write-Host "Running: $($Item.Name)" -ForegroundColor Cyan
        Write-Host ('=' * 50) -ForegroundColor DarkCyan
        Write-Host ''

        try {

            Invoke-GitHubScript `
                -Url $Item.Url `
                -FunctionName $Item.Name

            $script:FunctionStatus[$Item.Name] = 'Success'

            Write-PCBuildLog "Success: $($Item.Name)"

            Write-Host ''
            Write-Host "[SUCCESS] $($Item.Name)" -ForegroundColor Green
        }
        catch {

            $script:FunctionStatus[$Item.Name] = 'Failed'

            Write-PCBuildLog "Failure: $($Item.Name)" 'ERROR'
            Write-PCBuildLog $_.Exception.ToString() 'ERROR'

            Write-Host ''
            Write-Host "[FAILED] $($Item.Name)" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Yellow
        }

        Read-Host "`nPress Enter"

    } while ($true)
}

$script:Config = $null
  
function Set-PCBuildConfig {
    param([object]$Config)
    $script:Config = $Config
}

function Get-PCBuildConfig {
    $script:Config
}

# Module Exports
if ($MyInvocation.MyCommand.Module) {
  Export-ModuleMember -Function `
    Get-GitHubItems,
    Invoke-GitHubScript,
    Set-PCBuildConfig,
    Get-PCBuildConfig,
    Show-PCBuildMenu,
}

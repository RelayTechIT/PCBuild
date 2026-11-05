# Module Configuration
$script:ManifestUri = 'https://raw.githubusercontent.com/RelayTechIT/PCBuild/main/Public/manifest.json'
$script:FunctionStatus = @{}
$script:CachedItems = $null

# Menu Item Discovery
function Get-GitHubItems {

    if ($script:CachedItems) {
        return $script:CachedItems
    }

    try {

        $script:CachedItems = Invoke-RestMethod `
            -Uri $script:ManifestUri `
            -ErrorAction Stop

        return $script:CachedItems
    }
    catch {
        throw "Failed to load manifest.json. $($_.Exception.Message)"
    }
}

# Script Execution
function Invoke-GitHubScript {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$FunctionName
    )

    Write-Host "Downloading $FunctionName..." -ForegroundColor Cyan

    $Code = (Invoke-WebRequest `
        -Uri $Url `
        -UseBasicParsing `
        -ErrorAction Stop).Content

    . ([ScriptBlock]::Create($Code))

    if (-not (Get-Command $FunctionName -ErrorAction SilentlyContinue)) {
        throw "Function '$FunctionName' was not loaded."
    }

    Write-Host "Executing $FunctionName..." -ForegroundColor Yellow

    & $FunctionName
}

# Menu Display
function Show-PCBuildMenu {

    do {

        Clear-Host

        Write-Host ('=' * 50) -ForegroundColor DarkGreen
        Write-Host 'PC BUILD MENU' -ForegroundColor Green
        Write-Host ('=' * 50) -ForegroundColor DarkGreen
        Write-Host ''

        $Items = Get-GitHubItems
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
                    default { 'White' }
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

            Write-Host ''
            Write-Host "[SUCCESS] $($Item.Name)" -ForegroundColor Green
        }
        catch {

            $script:FunctionStatus[$Item.Name] = 'Failed'

            Write-Host ''
            Write-Host "[FAILED] $($Item.Name)" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Yellow
        }

        Read-Host "`nPress Enter"

    } while ($true)
}

# Module Exports
if ($MyInvocation.MyCommand.Module) {
    Export-ModuleMember -Function Get-GitHubItems, Invoke-GitHubScript, Show-PCBuildMenu
}

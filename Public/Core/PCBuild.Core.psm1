# Repository Info
$script:RepoOwner = 'RelayTechIT'
$script:RepoName = 'PCBuild'

# Execution status tracking
$script:FunctionStatus = @{}

# Cache downloaded menu items for the session
$script:CachedItems = $null

# ==================================================
# Get-GitHubItems
# Retrieves all available scripts from GitHub and builds the menu inventory.
# ==================================================
function Get-GitHubItems {

    # Return cached copy if already loaded
    if ($script:CachedItems) {
        return $script:CachedItems
    }

    $Items = @()

    foreach ($Category in @(
        'Software',
        'System',
        'Cleanup',
        'Security'
    )) {

        try {

            $Url = "https://api.github.com/repos/$script:RepoOwner/$script:RepoName/contents/Public/$Category"

            Write-Host "Loading $Category..." -ForegroundColor DarkGray

            $Files = Invoke-RestMethod -Uri $Url -ErrorAction Stop

            foreach ($File in $Files) {

                if ($File.name -notlike '*.ps1') {
                    continue
                }

                $Items += [PSCustomObject]@{
                    Category = $Category
                    Name     = [System.IO.Path]::GetFileNameWithoutExtension($File.name)
                    Url      = $File.download_url
                    Type     = 'GitHub'
                }
            }
        }
        catch {

            Write-Host ''
            Write-Host "Failed to load category: $Category" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Yellow
        }
    }

    $script:CachedItems = $Items

    return $Items
}

# ==================================================
# Invoke-GitHubScript
# Downloads a script from GitHub, loads it into the
# current session, validates the function exists,
# then executes it.
# ==================================================
function Invoke-GitHubScript {

    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter(Mandatory)]
        [string]$FunctionName
    )

    Write-Host ''
    Write-Host "Downloading $FunctionName..." -ForegroundColor Cyan

    $Code = Invoke-RestMethod -Uri $Url -ErrorAction Stop

    Invoke-Expression $Code

    $Command = Get-Command $FunctionName -ErrorAction SilentlyContinue

    if (-not $Command) {
        throw "Function '$FunctionName' was not loaded from the downloaded script."
    }

    Write-Host "Executing $FunctionName..." -ForegroundColor Yellow

    & $FunctionName
}

# ==================================================
# Invoke-PCBuildItem
# Executes either a local function or a GitHub
# sourced function.
# ==================================================
function Invoke-PCBuildItem {

    param(
        [Parameter(Mandatory)]
        $Item
    )

    switch ($Item.Type) {

        'BuiltIn' {
            & $Item.Name
        }

        'GitHub' {
            Invoke-GitHubScript `
                -Url $Item.Url `
                -FunctionName $Item.Name
        }

        default {
            throw "Unknown item type: $($Item.Type)"
        }
    }
}

# ==================================================
# Show-PCBuildMenu
# The Main interactive console menu, all dynamic baby.
# ==================================================
function Show-PCBuildMenu {

    do {

        Clear-Host

        Write-Host '==================================================' -ForegroundColor DarkGreen
        Write-Host '                  PC BUILD MENU' -ForegroundColor Green
        Write-Host '==================================================' -ForegroundColor DarkGreen
        Write-Host ''

        $Items = Get-GitHubItems
        $Lookup = @{}
        $Index = 1

        foreach ($Category in @(
            'Software',
            'System',
            'Cleanup',
            'Security'
        )) {

            $CategoryItems = $Items |
                Where-Object Category -eq $Category |
                Sort-Object Name

            if (-not $CategoryItems) {
                continue
            }

            Write-Host $Category.ToUpper() -ForegroundColor Cyan
            Write-Host ('-' * $Category.Length)

            foreach ($Item in $CategoryItems) {

                $Color = 'White'

                if ($script:FunctionStatus.ContainsKey($Item.Name)) {

                    switch ($script:FunctionStatus[$Item.Name]) {

                        'Success' { $Color = 'Green' }
                        'Failed'  { $Color = 'Red' }
                    }
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

        if ($Choice -eq '0') {
            break
        }

        if ($Choice -notmatch '^\d+$') {
            continue
        }

        $Choice = [int]$Choice

        if (-not $Lookup.ContainsKey($Choice)) {
            continue
        }

        $Item = $Lookup[$Choice]

        Clear-Host

        Write-Host '==================================================' -ForegroundColor DarkCyan
        Write-Host " Running: $($Item.Name)" -ForegroundColor Cyan
        Write-Host '==================================================' -ForegroundColor DarkCyan
        Write-Host ''

        try {

            Invoke-PCBuildItem -Item $Item

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

        Write-Host ''
        Read-Host 'Press Enter to return to the menu'

    } while ($true)
}

# ==================================================
# Module Exports
# ==================================================
Export-ModuleMember -Function `
    Get-GitHubItems, `
    Invoke-GitHubScript, `
    Invoke-PCBuildItem, `
    Show-PCBuildMenu

# Repository Configuration
$script:RepoOwner = 'RelayTechIT'
$script:RepoName = 'PCBuild'
$script:Categories = @('Software', 'System', 'Cleanup', 'Security')
$script:FunctionStatus = @{}
$script:CachedItems = $null

$script:GitHubHeaders = @{
    'User-Agent' = 'PCBuild'
    'Accept' = 'application/vnd.github+json'
}

# GitHub Request Helper
function Invoke-PCBuildGitHubRequest {
    param(
        [Parameter(Mandatory)]
        [string]$Uri
    )

    Invoke-RestMethod -Uri $Uri -Headers $script:GitHubHeaders -ErrorAction Stop
}

# GitHub Item Discovery
function Get-GitHubItems {

    if ($script:CachedItems) { return $script:CachedItems }

    $Items = foreach ($Category in $script:Categories) {

        try {

            $Files = Invoke-PCBuildGitHubRequest `
                -Uri "https://api.github.com/repos/$script:RepoOwner/$script:RepoName/contents/Public/$Category"

            foreach ($File in $Files) {

                if ($File.name -notlike '*.ps1') { continue }

                [PSCustomObject]@{
                    Category = $Category
                    Name = [IO.Path]::GetFileNameWithoutExtension($File.name)
                    Url = $File.download_url
                }
            }
        }
        catch {
            Write-Host "[FAILED] $Category" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Yellow
        }
    }

    $script:CachedItems = $Items

    return $Items
}

# GitHub Script Execution
function Invoke-GitHubScript {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$FunctionName
    )

    Write-Host "Downloading $FunctionName..." -ForegroundColor Cyan

    $Code = Invoke-PCBuildGitHubRequest -Uri $Url

    Invoke-Expression $Code

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

        foreach ($Category in $script:Categories) {

            $CategoryItems = $Items | Where-Object Category -eq $Category | Sort-Object Name

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

        $Item = $Lookup[[int]$Choice]

        if (-not $Item) { continue }

        Clear-Host

        Write-Host ('=' * 50) -ForegroundColor DarkCyan
        Write-Host "Running: $($Item.Name)" -ForegroundColor Cyan
        Write-Host ('=' * 50) -ForegroundColor DarkCyan
        Write-Host ''

        try {

            Invoke-GitHubScript -Url $Item.Url -FunctionName $Item.Name

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
Export-ModuleMember -Function Get-GitHubItems, Invoke-GitHubScript, Show-PCBuildMenu

$script:RepoOwner = "RelayTechIT"
$script:RepoName = "PCBuild"
$script:FunctionStatus = @{}

function Get-GitHubItems {

    $Items = @()

    foreach ($Category in @('Software', 'System', 'Cleanup')) {

        try {

            $Url = "https://api.github.com/repos/$script:RepoOwner/$script:RepoName/contents/Public/$Category"

            $Files = Invoke-RestMethod -Uri $Url

            foreach ($File in $Files) {

                if ($File.name -notlike '*.ps1') { continue }

                $Items += [PSCustomObject]@{
                    Category = $Category
                    Name = $File.name.Replace('.ps1', '')
                    Url = $File.download_url
                    Type = 'GitHub'
                }
            }
        }
        catch {

            Write-Host ""
            Write-Host "Unable to load category: $Category" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Yellow
        }
    }
    

    }

    return $Items
}

function Invoke-GitHubScript {


    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter(Mandatory)]
        [string]$FunctionName
    )

    Write-Host ""
    Write-Host "Downloading $FunctionName..." -ForegroundColor Cyan

    $Code = Invoke-RestMethod -Uri $Url

    Invoke-Expression $Code

    if (-not (Get-Command $FunctionName -ErrorAction SilentlyContinue)) {
        throw "Function '$FunctionName' was not loaded."
    }

    Write-Host "Executing $FunctionName..." -ForegroundColor Yellow

    & $FunctionName
}

function Invoke-PCBuildItem {
    param(
        [Parameter(Mandatory)]
        $Item
    )
    if ($Item.Type -eq 'BuiltIn') {
        & $Item.Name
    }
    else {
        Invoke-GitHubScript `
            -Url $Item.Url `
            -FunctionName $Item.Name
    }
}

function Show-PCBuildMenu {
    do {

        Clear-Host
        Write-Host "==================================================" -ForegroundColor DarkGreen
        Write-Host "                  PC BUILD MENU" -ForegroundColor Green
        Write-Host "==================================================" -ForegroundColor DarkGreen
        Write-Host ""
        $Items = Get-GitHubItems
        $Lookup = @{}
        $Index = 1

        foreach ($Category in @('Software', 'System', 'Cleanup', 'Security')) {

            $CategoryItems = $Items |
                Where-Object Category -eq $Category |
                Sort-Object Name

            if (-not $CategoryItems) { continue }

            Write-Host $Category.ToUpper() -ForegroundColor Cyan
            Write-Host ("-" * $Category.Length)

            foreach ($Item in $CategoryItems) {

                $Color = 'White'

                if ($script:FunctionStatus.ContainsKey($Item.Name)) {

                    switch ($script:FunctionStatus[$Item.Name]) {

                        'Success' { $Color = 'Green' }
                        'Failed' { $Color = 'Red' }
                    }
                }

                Write-Host " [$Index] " -ForegroundColor Yellow -NoNewline
                Write-Host $Item.Name -ForegroundColor $Color

                $Lookup[$Index] = $Item

                $Index++
            }

            Write-Host ""
        }

        Write-Host " [0] Exit" -ForegroundColor Red
        Write-Host ""

        $Choice = Read-Host "Selection"

        if ($Choice -eq '0') { break }
        if ($Choice -notmatch '^\d+$') { continue }

        $Choice = [int]$Choice

        if (-not $Lookup.ContainsKey($Choice)) { continue }

        $Item = $Lookup[$Choice]

        Clear-Host

        Write-Host "==================================================" -ForegroundColor DarkCyan
        Write-Host " Running: $($Item.Name)" -ForegroundColor Cyan
        Write-Host "==================================================" -ForegroundColor DarkCyan
        Write-Host ""

        try {

            Invoke-PCBuildItem -Item $Item

            $script:FunctionStatus[$Item.Name] = 'Success'

            Write-Host ""
            Write-Host "[SUCCESS] $($Item.Name)" -ForegroundColor Green
        }
        catch {

            $script:FunctionStatus[$Item.Name] = 'Failed'

            Write-Host ""
            Write-Host "[FAILED] $($Item.Name)" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }

        Write-Host ""
        Read-Host "Press Enter to return to the menu"

    } while ($true)
}

Export-ModuleMember -Function `
    Get-GitHubItems,
    Invoke-GitHubScript,
    Invoke-PCBuildItem,
    Show-PCBuildMenu

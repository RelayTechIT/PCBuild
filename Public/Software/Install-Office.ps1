function Install-Office {
    winget install --id Microsoft.Office --silent --source winget --accept-package-agreements --accept-source-agreements
}

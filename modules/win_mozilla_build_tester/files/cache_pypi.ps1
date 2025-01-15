# Set the base URL and the destination folder
$baseUrl = "https://pypi.pub.build.mozilla.org/pub/"
$destinationFolder = "C:\pip-cache"

# Fetch all href links from the base URL
$fileLinks = (Invoke-WebRequest -Uri $baseUrl).Links.Href

# Filter for Windows-specific or any-platform packages
$filteredLinks = $fileLinks | Where-Object {
    ($_ -match '\.(whl|tar\.gz|zip)$') -and (
        $_ -match '(win32|win_amd64|win_arm)' -or
        $_ -match 'none-any'
    )
}

# Loop through each filtered link and download the file
foreach ($fileName in $filteredLinks) {
    # Download the file
    try {
        Invoke-WebRequest -Uri $fileUrl -OutFile "C:\pip-cache\$filename" -ErrorAction Stop
    } catch {
        Write-Warning "Failed to download $fileUrl $_"
    }
}

Write-Host "Download completed!"

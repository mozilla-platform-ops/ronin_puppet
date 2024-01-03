## Check if PowershellYAML is installed
if (-not (Get-Command ConvertFrom-Yaml -ErrorAction Stop)) {
    Install-Module "powershell-yaml" -Repository PSGallery -Scope CurrentUser -Confirm:$false
}

## Set some vars
$azure_public_ips_json = "https://www.microsoft.com/en-us/download/confirmation.aspx?id=56519"
$workerimages_yml = "https://hg.mozilla.org/ci/ci-configuration/raw-file/tip/worker-images.yml"
$temp = [System.IO.Path]::GetTempPath() ## cross-platform temp directory

## Grab the unique json file that hosts azure public ips
$json_url = (Invoke-WebRequest $azure_public_ips_json).Links.href | Where-Object {$_ -match "\.json"} | Select-Object -Unique
## If there's more than 1 result, stop
if ($json_url.count -gt 1) {
    Write-Error "More than 1 azure public ip json file"
}
## Import the full json file
$azure_public_ips = Invoke-RestMethod $json_url

## Download the worker-images yml and select the windows-only regions
$null = Invoke-WebRequest -Uri $workerimages_yml -OutFile $temp\worker-images.yml
$data = Convertfrom-Yaml (Get-Content $temp\worker-images.yml -raw)
$windows = $data.keys | Where-Object {$_ -match "win"}
## skip the property deployment_id
$regions = foreach ($pool in $windows) {
    $data[$pool].values.keys | Where-Object {$_ -ne "deployment_id"}
}

## Grab the regions and remove the hyphen since the azure json file region properties do not use hyphens
$all_required_az_regions_exist = $regions | Sort-Object -Unique | ForEach-Object {$_ -replace "-"}

## if the region name contains Storage.* and it's not stage, return the value(s)
$az_blob_ips = foreach ($region in $azure_public_ips.values) {
    if ($region.name -match "Storage\." -and $region.name -notmatch "Stage") {
        if ($region.properties.region -in $all_required_az_regions_exist) {
            $region
        }
    }
}

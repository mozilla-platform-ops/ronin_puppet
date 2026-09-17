if (Test-Path "D:\secrets\pat.txt") {
    # Datacenter/MDC1 deploy: PAT copied to the secrets drive by OS-deploy.ps1.
    $pat = Get-Content "D:\secrets\pat.txt"
}
elseif ($env:custom_win_github_pat) {
    # Image bake: the guest has no D: secrets drive. The bake passes the token as an
    # environment variable (win-hw-wim bake-bootstrap, from the pipeline / GHA
    # GITHUB_TOKEN). Build-scoped; never written to disk or captured in the WIM.
    $pat = $env:custom_win_github_pat
}
else {
    $pat = $null
}
Write-host "custom_win_github_pat=$pat"

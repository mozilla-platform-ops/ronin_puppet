if (Test-Path "D:\secrets\pat.txt") {
    $pat = Get-Content "D:\secrets\pat.txt"
}
else {
    $pat = $null
}
Write-host "custom_win_github_pat=$pat"
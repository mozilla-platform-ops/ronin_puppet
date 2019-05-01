$url = 'https://tooltool.mozilla-releng.net/'
$localPath = ('{0}\builds\' -f $env:SystemDrive)
$tokenPath = ('{0}\builds\relengapi.tok' -f $env:SystemDrive)
$bearerToken = (Get-Content -Path $tokenPath -Raw)
$webClient = New-Object -TypeName 'System.Net.WebClient'
$webClient.Headers.Add('Authorization', ('Bearer {0}' -f $bearerToken))
$webClient.DownloadFile($url, $localPath)

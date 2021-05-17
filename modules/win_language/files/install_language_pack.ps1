$pack=$args[0]

$languageList = Get-WinUserLanguageList
if (@($languageList | ? { $_.LanguageTag -eq "$pack" }).Length -lt 1) {
  $languageList.Add("$pack")
  Set-WinUserLanguageList -LanguageList $languageList -Force
}

$Url = "https://roninpuppetassets.blob.core.windows.net/binaries/Microsoft.AV1VideoExtension_1.1.62361.0_neutral_~_8wekyb3d8bbwe.AppxBundle"
Invoke-WebRequest -Uri $url -OutFile "$ENV:TEMP\Microsoft.AV1VideoExtension_1.1.62361.0_neutral_~_8wekyb3d8bbwe.AppxBundle"

try {
    Add-AppxPackage -Path "$ENV:TEMP\Microsoft.AV1VideoExtension_1.1.62361.0_neutral_~_8wekyb3d8bbwe.AppxBundle" -ErrorAction "Stop"
    Exit 0
}
catch {
    Exit 1
}

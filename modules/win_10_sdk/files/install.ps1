## Download it
Invoke-WebRequest -Uri "https://roninpuppetassets.blob.core.windows.net/binaries/winsdksetup.exe" -OutFile "C:/winsdksetup.exe"

## Install it
Start-Process -FilePath "C:/winsdksetup.exe" -ArgumentList @(
    "/q",
    "/norestart"
) -Wait -NoNewWindow
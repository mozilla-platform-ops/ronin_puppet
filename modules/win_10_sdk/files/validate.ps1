## Validate it exists
if (Test-Path "${ENV:ProgramFiles(x86)}\Microsoft SDKs\Windows Kits\10\ExtensionSDKs\Microsoft.UniversalCRT.Debug\10.0.19041.0\SDKManifest.xml") {
    exit 1
}
else {
    exit 0
}
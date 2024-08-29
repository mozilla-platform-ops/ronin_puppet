choco install "googlechrome" -y "--ignore-checksums" "--ignore-package-exit-codes" --no-progress

if ($LASTEXITCODE -ne 0) {
    throw "Failed to install Google Chrome"
    Write-Log -message ('{0} :: Failed to install Google Chrome - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    exit 1
}
else {
    Write-Log -message ('{0} :: Successfully installed Google Chrome - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    exit 0
    Continue
}
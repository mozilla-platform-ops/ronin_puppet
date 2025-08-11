# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Variables from Puppet
$HgExePath = '<%= @hg_exe_path %>'
$RepositoryUrl = '<%= @mozilla_unified_url %>'
$CheckoutPath = '<%= @checkout_path %>'
# Execute the clone command
$process = Start-Process -FilePath $HgExePath -ArgumentList "clone", $RepositoryUrl, $CheckoutPath -Wait -PassThru -NoNewWindow
    
if ($process.ExitCode -eq 0) {
    Write-Log "Clone completed successfully"
        
    # Verify the clone was successful
    if (Test-Path $hgDir) {
        Write-Log "Verification: .hg directory created successfully"
        exit 0
    }
    else {
        Write-Log "ERROR: Clone appeared successful but .hg directory not found"
        exit 1
    }
}
else {
    Write-Log "ERROR: Clone failed with exit code $($process.ExitCode)"
    exit $process.ExitCode
}
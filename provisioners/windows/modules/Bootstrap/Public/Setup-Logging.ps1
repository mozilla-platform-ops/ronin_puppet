function Setup-Logging {
    param (
      [string] $ext_src = "https://s3-us-west-2.amazonaws.com/ronin-puppet-package-repo/Windows/prerequisites",
      [string] $local_dir = "$env:systemdrive\BootStrap",
      [string] $nxlog_msi = "nxlog-ce-2.10.2150.msi",
      [string] $nxlog_conf = "nxlog.conf",
      [string] $nxlog_pem  = "papertrail-bundle.pem",
      [string] $nxlog_dir   = "$env:systemdrive\Program Files (x86)\nxlog"
    )
    begin {
      Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
      New-Item -ItemType Directory -Force -Path $local_dir

      Invoke-WebRequest  $ext_src/$nxlog_msi -outfile $local_dir\$nxlog_msi -UseBasicParsing
      msiexec /i $local_dir\$nxlog_msi /passive
      while (!(Test-Path "$nxlog_dir\conf\")) { Start-Sleep 10 }
      Invoke-WebRequest  $ext_src/$nxlog_conf -outfile "$nxlog_dir\conf\$nxlog_conf" -UseBasicParsing
      while (!(Test-Path "$nxlog_dir\conf\")) { Start-Sleep 10 }
      Invoke-WebRequest  $ext_src/$nxlog_pem -outfile "$nxlog_dir\cert\$nxlog_pem" -UseBasicParsing
      Restart-Service -Name nxlog -force
    }
    end {
      Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
}
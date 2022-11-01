﻿function Install-ZipPrerequ {
    param (
      [string] $ext_src = "https://s3-us-west-2.amazonaws.com/ronin-puppet-package-repo/Windows/prerequisites",
      [string] $local_dir = "$env:systemdrive\BootStrap",
      [string] $work_dir = "$env:systemdrive\scratch",
      [string] $git = "Git-2.18.0-64-bit.exe",
      [string] $puppet = "puppet-agent-6.0.0-x64.msi"
    )
    begin {
      Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {

      remove-item $local_dir   -Recurse  -force
      New-Item -path $work_dir -ItemType "directory"
      Set-location -path $work_dir
      Invoke-WebRequest -Uri  $ext_src/BootStrap.zip  -UseBasicParsing -OutFile $work_dir\BootStrap.zip
      Expand-Archive -path $work_dir\BootStrap.zip -DestinationPath $env:systemdrive\
      Read-Host "Enusre c:\bootstrap\secrets\vault.yam is present, and then press eneter to continue"
      Set-location -path $local_dir
      remove-item $work_dir   -Recurse  -force

      Start-Process $local_dir\$git /verysilent -wait
      Write-Log -message  ('{0} :: Git installed " {1}' -f $($MyInvocation.MyCommand.Name), ("$git")) -severity 'DEBUG'
      Start-Process  msiexec -ArgumentList "/i", "$local_dir\$puppet", "/passive" -wait
      Write-Log -message  ('{0} :: Puppet installed " {1}' -f $($MyInvocation.MyCommand.Name), ("$puppet")) -severity 'DEBUG'

    }
    end {
      Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
  }

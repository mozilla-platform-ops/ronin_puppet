function Bootstrap-AzPuppet {
    param (
      [int] $exit,
      [string] $lock = "$env:programdata\PuppetLabs\ronin\semaphore\ronin_run.lock",
      [int] $last_exit = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").last_run_exit,
      [string] $run_to_success = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").runtosuccess,
      [string] $restorable = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").restorable,
      [string] $nodes_def = "$env:systemdrive\ronin\manifests\nodes\odes.pp",
      [string] $puppetfile = "$env:systemdrive\ronin\Puppetfile",
      [string] $logdir = "$env:systemdrive\logs",
      [string] $datetime = (get-date -format yyyyMMdd-HHmm),
      [string] $flagfile = "$env:programdata\PuppetLabs\ronin\semaphore\task-claim-state.valid",
      [string] $mozilla_key = "HKLM:\SOFTWARE\Mozilla\",
      [string] $ronnin_key = "$mozilla_key\ronin_puppet",
      [string] $sourceOrg = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet\source").Organisation,
      [string] $sourceRepo = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet\source").Repository,
      [string] $sourceRev = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet\source").Revision,
      [string] $restore_needed = (Get-ItemProperty "HKLM:\SOFTWARE\Mozilla\ronin_puppet").restore_needed,
      [string] $stage = (Get-ItemProperty -path "HKLM:\SOFTWARE\Mozilla\ronin_puppet").bootstrap_stage,
      [string] $deploymentID = ((((Invoke-WebRequest -Headers @{'Metadata' = $true } -UseBasicParsing -Uri ('http://169.254.169.254/metadata/instance?api-version=2019-06-04')).Content) | ConvertFrom-Json).compute.tagsList | ? { $_.name -eq ('deploymentId') })[0].value
    )
    begin {
      Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {

      Set-Location $env:systemdrive\ronin
      If (!(test-path $logdir\old)) {
        New-Item -ItemType Directory -Force -Path $logdir\old
      }
      $git_hash = (git rev-parse --short HEAD)
      if ($git_hash -ne $deploymentID) {
        If (($stage -eq 'setup') -or ($stage -eq 'inprogress')) {
          git checkout $deploymentID
          $git_exit = $LastExitCode
          if ($git_exit -eq 0) {
            Set-ItemProperty -Path HKLM:\SOFTWARE\Mozilla\ronin_puppet -name githash -type  string -value $git_hash
            Write-Log -message  ('{0} :: Setting Ronin Puppet HEAD to {1} .' -f $($MyInvocation.MyCommand.Name), ($deploymentID)) -severity 'DEBUG'
          }
          else {
            Write-Log -message  ('{0} :: Git checkout failed! https://github.com/{1}/{2}. Branch: {3} Head: {4}.' -f $($MyInvocation.MyCommand.Name), ($sourceOrg), ($sourceRepo), ($sourceRev), ($deploymentID) ) -severity 'DEBUG'
            Move-item -Path $ronin_repo\manifests\nodes.pp -Destination $env:TEMP\nodes.pp
            Move-item -Path $ronin_repo\data\secrets\vault.yaml -Destination $env:TEMP\vault.yaml
            Remove-Item -Recurse -Force $ronin_repo
            Start-Sleep -s 2
            git clone --single-branch --branch $sourceRev https://github.com/$sourceOrg/$sourceRepo $ronin_repo
            git checkout $deploymentID
            $git_exit = $LastExitCode
            if ($git_exit -ne 0) {
              Write-Log -message  ('{0} :: FAILED to set  Ronin Puppet HEAD to {1}! Check if deploymentID is valid. Giving up on bootstrsaping!' -f $($MyInvocation.MyCommand.Name), ($deploymentID)) -severity 'DEBUG'
              #shutdown @('-s', '-t', '0', '-c', 'Shutdown;Bootstrapping failed on possible invalid deploymentID ', '-f', '-d', '4:5')
              exit 423
            }
            Write-Log -message  ('{0} :: Setting Ronin Puppet HEAD to {1} .' -f $($MyInvocation.MyCommand.Name), ($deploymentID)) -severity 'DEBUG'
            Move-item -Path $env:TEMP\nodes.pp -Destination $ronin_repo\manifests\nodes.pp
            Move-item -Path $env:TEMP\vault.yaml -Destination $ronin_repo\data\secrets\vault.yaml
          }
        }
      }
      else {
        Write-Log -message  ('{0} ::Ronin Puppet HEAD is set to {1} .' -f $($MyInvocation.MyCommand.Name), ($deploymentID)) -severity 'DEBUG'
      }
      Set-ItemProperty -Path "HKLM:\SOFTWARE\Mozilla\ronin_puppet" -Name 'bootstrap_stage' -Value 'inprogress'

      # Setting Env variabes for PuppetFile install and Puppet run
      # The ssl variables are needed for R10k
      Write-Log -message  ('{0} :: Setting Puppet enviroment.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
      $env:path = $env:path = "$env:programfiles\Puppet Labs\Puppet\bin;$env:path"
      $env:SSL_CERT_FILE = "$env:programfiles\Puppet Labs\Puppet\puppet\ssl\cert.pem"
      $env:SSL_CERT_DIR = "$env:programfiles\Puppet Labs\Puppet\puppet\ssl"
      $env:FACTER_env_windows_installdir = "$env:programfiles\Puppet Labs\Puppet"
      $env:HOMEPATH = "\Users\Administrator"
      $env:HOMEDRIVE = "C:"
      $env:PL_BASEDIR = "$env:programfiles\Puppet Labs\Puppet"
      $env:PUPPET_DIR = "$env:programfiles\Puppet Labs\Puppet"
      $env:RUBYLIB = "$env:programfiles\Puppet Labs\Puppet\lib"
      $env:USERNAME = "Administrator"
      $env:USERPROFILE = "$env:systemdrive\Users\Administrator"

      Write-Log -message  ('{0} :: Moving old logs.' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
      Get-ChildItem -Path $logdir\*.log -Recurse | Move-Item -Destination $logdir\old -ErrorAction SilentlyContinue
      Write-Log -message  ('{0} :: Running Puppet apply .' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
      puppet apply manifests\nodes.pp --onetime --verbose --no-daemonize --no-usecacheonfailure --detailed-exitcodes --no-splay --show_diff --modulepath=modules`;r10k_modules --hiera_config=win_hiera.yaml --logdest $logdir\$datetime-bootstrap-puppet.log
      [int]$puppet_exit = $LastExitCode

      if ($run_to_success -eq 'true') {
        if (($puppet_exit -ne 0) -and ($puppet_exit -ne 2)) {
          if (($last_exit -eq 0) -or ($puppet_exit -eq 2)) {
            Write-Log -message  ('{0} :: Puppet apply failed.  ' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            Set-ItemProperty -Path "$ronnin_key" -name last_run_exit -value $puppet_exit
            #shutdown ('-r', '-t', '0', '-c', 'Reboot; Puppet apply failed', '-f', '-d', '4:5')
            #return
            #exit 2
            exit 0
          }
          elseif (($last_exit -ne 0) -or ($puppet_exit -ne 2)) {
            Set-ItemProperty -Path "$ronnin_key" -name last_run_exit -value $puppet_exit
            Write-Log -message  ('{0} :: Puppet apply failed multiple times. Waiting 5 minutes beofre Reboot' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
            sleep 300
            #return
            #shutdown @('-r', '-t', '0', '-c', 'Reboot; Puppet apply failed', '-f', '-d', '4:5')
            exit 0
            # exit 2
          }
        }
        elseif (($puppet_exit -match 0) -or ($puppet_exit -match 2)) {
          Write-Log -message  ('{0} :: Puppet apply successful' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
          Set-ItemProperty -Path "$ronnin_key" -name last_run_exit -value $puppet_exit
          Set-ItemProperty -Path "$ronnin_key" -Name 'bootstrap_stage' -Value 'complete'
          #shutdown @('-r', '-t', '0', '-c', 'Reboot; Bootstrap complete', '-f', '-d', '4:5')
          #Write-Log -message  ('{0} :: Puppet apply successful. Waiting on Cloud-Image-Builder pickup' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
          #return
          exit 0
          # exit 2
        }
        else {
          Write-Log -message  ('{0} :: Unable to detrimine state post Puppet apply' -f $($MyInvocation.MyCommand.Name)) -severity 'DEBUG'
          Set-ItemProperty -Path "$ronnin_key" -name last_run_exit -value $last_exit
          Start-sleep -s 300
          #return
          #shutdown @('-r', '-t', '0', '-c', 'Reboot; Unveriable state', '-f', '-d', '4:5')
          exit 0
          #exit 2
        }
      }
    }
    end {
      Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
  }

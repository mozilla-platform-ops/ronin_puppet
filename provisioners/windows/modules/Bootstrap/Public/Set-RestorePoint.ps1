Function Set-RestorePoint {
    param (
      [string] $mozilla_key = "HKLM:\SOFTWARE\Mozilla\",
      [string] $ronnin_key = "$mozilla_key\ronin_puppet",
      [string] $date = (Get-Date -Format "yyyy/mm/dd-HH:mm"),
      [int32] $max_boots
    )
    begin {
      Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
    process {
      vssadmin delete shadows /all /quiet
      powershell.exe -Command Checkpoint-Computer -Description "default"

      if (!(Test-Path $ronnin_key)) {
        New-Item -Path HKLM:\SOFTWARE -Name Mozilla â€“Force
        New-Item -Path HKLM:\SOFTWARE\Mozilla -name ronin_puppet â€“Force
      }

      New-ItemProperty -Path "$ronnin_key" -name "restorable" -PropertyType  string -value yes
      New-ItemProperty -Path "$ronnin_key" -name "reboot_count" -PropertyType  Dword -value 0
      New-ItemProperty -Path "$ronnin_key" -name "last_restore_point" -PropertyType  string -value $date
      New-ItemProperty -Path "$ronnin_key" -name "restore_needed" -PropertyType  string -value false
      New-ItemProperty -Path "$ronnin_key" -name "max_boots" -PropertyType  Dword -value $max_boots
    }
    end {
      Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
    }
  }

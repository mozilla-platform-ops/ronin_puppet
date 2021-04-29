#!powershell.exe

function ErroMessage {
    @'
{
  "_error": {
    "kind": "facts/noname",
    "msg": "Could not determine OS name"
  }
}
'@   
}

# The number 2 in the condition below is the value of
# the [System.PlatformID]::Win32NT constant. We don't
# use the constant here as it doesn't work on Windows
# Server Core.
if ([System.Environment]::OSVersion.Platform -gt 2) {
    ErroMessage
} elseif ($env:PT__task -eq 'facts' -and (Get-Command facter -ErrorAction SilentlyContinue)) {
  $facter_version = facter -v | Out-String
  if ($facter_version -match '^[0-2]') {
    facter -p --json
  } elseif ($facter_version -match '^3') {
    facter -p --json --show-legacy
  } else {
    $puppet_version = puppet --version | Out-String
    if ($puppet_version -match '^6') {
      # puppet 6 with facter 4
      facter --json --show-legacy
    } else {
      # puppet 7 with facter 4
      puppet facts show --show-legacy --render-as json
    }
  }
} else {
    $release = [System.Environment]::OSVersion.Version.ToString() -replace '\.[^.]*\z'
    $version = $release -replace '\.[^.]*\z'

    # CommandNotFoundException for powershell <=2 is terminating error
    try {
        # This fails for regular users unless explicitly enabled
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $consumerrel = $os.ProductType -eq '1'
    }
    catch [System.Management.Automation.CommandNotFoundException] {
        ErroMessage
        exit
    }

    $release = switch($version){
        '10.0'{ 
            if ($consumerrel) { '10' } else {
                if ($os.BuildNumber -ge 17763) { '2019' } else {'2016' }
            }
        }
        '6.3' { if ($consumerrel) { '8.1' } else { '2012 R2' } }
        '6.2' { if ($consumerrel) { '8' } else { '2012' } }
        '6.1' { if ($consumerrel) { '7' } else { '2008 R2' } }
        '6.0' { if ($consumerrel) { 'Vista' } else { '2008' } }
        '5.2' { 
            if ($consumerrel) { 'XP' } else {
                if ($os.OtherTypeDescription -eq 'R2') { '2003 R2' } else { '2003' }
            }
        }
    }

    @"
{
  "os": {
    "name": "windows",
    "release": {
      "full": "$release",
      "major": "$release"
    },
    "family": "windows"
  }
}
"@
}

# Bootstrap Modules

Because of the various location and type of Windows workers the bootstrap functions are broken down into various modules.

## Common Module

Contains functions that are universal or used across multiple worker types or locations.

## Other Modules

Contains functions that are more specific to location or a specific subset of workers. I.e. Azure or aarch64 workers. These functions should be identifiable by there names. For example a function in the Azure module should have a prefix of "Az" such as AzBootstrap-Puppet.

The reason for the different modules is so it is easier to trace down what is happening during bootstrap. As opposed to a single module with functions with overly complex conditional language.

## Installing modules for bootstraping

Use the following function.
```
function InstallRoninModule {
  param (
    [string] $src_Organisation,
    [string] $src_Repository,
    [string] $src_Revision,
    [string] $moduleName,
    [string] $local_dir = "$env:systemdrive\BootStrap",
    [string] $filename = ('{0}.psm1' -f $moduleName),
    [string] $module_name = ($moduleName).replace(".pms1",""),
    [string] $modulesPath = ('{0}\Modules\{1}' -f $pshome, $moduleName),
    [string] $bootstrap_module = "$modulesPath\bootstrap",
    [string] $moduleUrl = ('https://raw.githubusercontent.com/{0}/{1}/{2}/provisioners/windows/modules/{3}' -f $src_Organisation, $src_Repository, $src_Revision, $filename)
  )
  begin {
    Write-Log -message ('{0} :: begin - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
  process {
    mkdir $bootstrap_module  -ErrorAction SilentlyContinue
    Invoke-WebRequest $moduleUrl -OutFile "$bootstrap_module\\$filename" -UseBasicParsing
    Get-Content -Encoding UTF8 "$bootstrap_module\\$filename" | Out-File -Encoding Unicode "$modulesPath\\$filename"
    Import-Module -Name $moduleName
    }
  end {
    Write-Log -message ('{0} :: end - {1:o}' -f $($MyInvocation.MyCommand.Name), (Get-Date).ToUniversalTime()) -severity 'DEBUG'
  }
}
```

Then in the bootstraps script.
```
    InstallRoninModule -moduleName common-bootstrap -src_Organisation $src_Organisation -src_Repository $src_Repository -src_Revision $src_Revision
    InstallRoninModule -moduleName azure-bootstrap -src_Organisation $src_Organisation -src_Repository $src_Repository -src_Revision $src_Revision
```

#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

Describe 'Package ACLs' -Tag IntegrationTests {
    It 'protects cached installers and extraction paths' {
        $nssm_dir = 'C:\nssm'
        $vac_dir = 'C:\VAC'
        $nssm_version = Get-HieraValue 'windows.nssm.version'
        $vac_package_dir = Get-HieraValue 'win-worker.variant.vac.package_dir', 'win-worker.vac.package_dir', 'windows.vac.package_dir'
        $vac_installer = Get-HieraValue 'win-worker.variant.vac.installer', 'win-worker.vac.installer', 'windows.vac.installer'
        $path = Join-Path $env:SystemDrive 'RoninPackages'
        $nssmRoot = [Environment]::ExpandEnvironmentVariables($nssm_dir)
        $nssmVersion = Join-Path $nssmRoot "nssm-$nssm_version"
        $nssmArch = Join-Path $nssmVersion 'win64'
        $items = @(Get-Item -LiteralPath $path, $nssmRoot, $nssmVersion, $nssmArch, (Join-Path $nssmArch 'nssm.exe') -ErrorAction Stop)
        $items += @(Get-ChildItem -LiteralPath $path -File)
        $vacRoot = [Environment]::ExpandEnvironmentVariables($vac_dir)
        if (Test-Path -LiteralPath $vacRoot) {
          $vacWork = Join-Path $vacRoot $vac_package_dir
          $items += @(Get-Item -LiteralPath $vacRoot, $vacWork, (Join-Path $vacWork $vac_installer) -ErrorAction Stop)
        }
        $expected = @('S-1-5-18', 'S-1-5-32-544', 'S-1-5-32-545')
        foreach ($item in $items) {
          $acl = Get-Acl -LiteralPath $item.FullName -ErrorAction Stop
          if (!$acl.AreAccessRulesProtected) { throw "Inherited package staging ACL: $($item.FullName)" }
          $rules = @($acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))
          if ($rules.Count -ne $expected.Count) { throw "Unexpected package staging ACL: $($item.FullName)" }
          foreach ($rule in $rules) {
            $sid = $rule.IdentityReference.Value
            if ($sid -notin $expected -or $rule.AccessControlType -ne 'Allow') { throw "Unexpected package staging ACE: $rule" }
            if ($sid -eq 'S-1-5-32-545' -and ($rule.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::Write)) {
              throw "Users can write to $($item.FullName)"
            }
          }
        }
        'Package and extraction ACLs passed'
    }
}

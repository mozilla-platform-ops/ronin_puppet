#Requires -Module @{ ModuleName = "Pester"; ModuleVersion = "6.2.0" }

Describe 'Worker ACLs' -Tag IntegrationTests {
    It 'keeps the runner configuration owned by SYSTEM' {
        (Get-Acl 'C:\worker-runner\runner.yml').GetOwner([System.Security.Principal.SecurityIdentifier]).Value | Should-Be 'S-1-5-18'
    }
    It 'restricts privileged worker paths' {
        $paths = @{
          'C:\generic-worker' = @('S-1-5-18', 'S-1-5-32-544', 'S-1-5-32-545')
          'C:\generic-worker\generic-worker.exe' = @('S-1-5-18', 'S-1-5-32-544', 'S-1-5-32-545')
          'C:\generic-worker\taskcluster-proxy.exe' = @('S-1-5-18', 'S-1-5-32-544', 'S-1-5-32-545')
          'C:\generic-worker\task-user-init.ps1' = @('S-1-5-18', 'S-1-5-32-544', 'S-1-5-32-545')
          'C:\worker-runner' = @('S-1-5-18', 'S-1-5-32-544')
          'C:\worker-runner\start-worker.exe' = @('S-1-5-18', 'S-1-5-32-544')
        }
        foreach ($path in $paths.Keys) {
          $acl = Get-Acl -LiteralPath $path -ErrorAction Stop
          if ($path -in @('C:\generic-worker', 'C:\worker-runner') -and !$acl.AreAccessRulesProtected) {
            throw "Inherited directory ACL: $path"
          }
          $rules = @($acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))
          if ($rules.Count -ne $paths[$path].Count) { throw "Unexpected ACL: $path" }
          foreach ($rule in $rules) {
            $sid = $rule.IdentityReference.Value
            $rights = if ($sid -eq 'S-1-5-32-545') {
              [System.Security.AccessControl.FileSystemRights]::ReadAndExecute -bor [System.Security.AccessControl.FileSystemRights]::Synchronize
            } else {
              [System.Security.AccessControl.FileSystemRights]::FullControl
            }
            if ($sid -notin $paths[$path] -or $rule.AccessControlType -ne 'Allow' -or $rule.FileSystemRights -ne $rights) {
              throw "Unexpected ACL entry on ${path}: $rule"
            }
          }
        }
        'Worker ACLs passed'
    }
}

# integration testing

## template for different behaviors on each OS

```ruby
# template

if os.family == 'debian' && os.release.start_with?('18.04')
  #
elsif os.family == 'debian' && os.release.start_with?('22.04')
  #
elsif os.family == 'debian' && os.release.start_with?('24.04')
  #
else
  # shouldn't be here
  # for other OS families or versions, show error
  describe command('false') do
    its(:exit_status) { should eq 0 }
    its(:stdout) { should_not match /NONO/ }
  end
end
```

## Windows

Windows Kitchen uses `kitchen-pester` 1.2.2 and Pester 6.2.0. The tests are in
`windows/pester/`, in separate files for each profile or component. For example,
`MicrosoftTools.Tests.ps1` checks Microsoft tools, `SystemProfiles.Tests.ps1`
checks system settings, and `ServiceProfiles.Tests.ps1` checks services and
scheduled tasks. Role conditions select checks within these shared files.
Linux and macOS keep their existing verifiers.

Run the Windows suite with the role and pool ID from the Windows CI matrix:

```sh
export KITCHEN_YAML=.kitchen_configs/kitchen.windows.yml
export PUPPET_ROLE=win116425h2azure
export WORKER_POOL_ID=win11-64-25h2
bundle exec kitchen test windows-win11-64-25h2
```

The existing Azure credentials, `KITCHEN_ADMIN_PASSWORD`, and `RONIN_REF` are
also required. The Windows GitHub Actions workflow sets these values.

Kitchen sends the role data and Windows defaults from the local checkout as
`RONIN_TEST_DATA`. Pester uses those values for version and role checks. It does
not read expected values from the configured VM. Shared checks run once per VM;
role conditions select the remaining checks.

The verifier installs Pester on the test VM and runs PowerShell there. It returns
JUnit XML and the generated command script to `test-results/<instance>/`,
including after test failures. The Windows CI job uploads these files as an
artifact. Test failures and discovery errors fail the Kitchen command.

Use PSScriptAnalyzer 1.25.0 to check and format the PowerShell files. The Windows
workflow checks both lint and formatting. From PowerShell at the repository root:

```powershell
$path = 'test/integration/windows/pester'
$settings = "$path/PSScriptAnalyzerSettings.psd1"
Invoke-ScriptAnalyzer -Path $path -Recurse -Settings $settings
Get-ChildItem $path -Recurse -Include *.ps1,*.psd1 | ForEach-Object {
    $formatted = Invoke-Formatter -ScriptDefinition (Get-Content $_.FullName -Raw) -Settings $settings
    [System.IO.File]::WriteAllText($_.FullName, $formatted)
}
```

The layout follows [dbatools' test structure](https://github.com/dataplat/dbatools/tree/development/tests):
separate files, setup in `BeforeAll`, named `Context` blocks where needed, and
short assertions. These tests use Pester 6 assertions. The analyzer checks syntax
for Windows PowerShell 5.1 and PowerShell 7.4. Its settings exclude unused-variable
warnings because Pester setup and dot-sourced settings pass variables between scopes.

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
`windows/pester/`. Linux and macOS keep their existing verifiers.

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

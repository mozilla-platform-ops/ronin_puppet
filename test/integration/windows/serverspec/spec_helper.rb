require 'serverspec'
require 'winrm'
require 'yaml'

module RoninKitchenWindows
  MANIFEST_PATH = File.expand_path('../pester/manifest.yml', __dir__)
  REMOTE_REPO_ROOT = ENV.fetch('RONIN_KITCHEN_REMOTE_ROOT', 'C:\\ronin_puppet')

  def self.pester_tests_for(role)
    manifest = YAML.load_file(MANIFEST_PATH)
    tests = manifest.fetch('roles', {}).fetch(role, {}).fetch('tests', [])
    raise "No Windows Pester tests configured for #{role}" if tests.empty?

    tests
  end

  def self.pester_command(role:, test_file:)
    script = File.join(REMOTE_REPO_ROOT, 'test', 'integration', 'windows', 'pester', 'Invoke-RoninKitchenPester.ps1')

    [
      'powershell.exe',
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy', 'Bypass',
      '-File', %("#{script}"),
      '-Role', %("#{role}"),
      '-TestFile', %("#{test_file}")
    ].join(' ')
  end
end

conn = WinRM::Connection.new(
  endpoint: "http://#{ENV.fetch('KITCHEN_HOSTNAME')}:5985/wsman",
  user: ENV.fetch('KITCHEN_USERNAME'),
  password: ENV.fetch('KITCHEN_PASSWORD'),
  transport: :plaintext,
  basic_auth_only: true,
  operation_timeout: 1800,
  receive_timeout: 1810
)

Specinfra.configuration.winrm = conn
set :backend, :winrm
set :os, :family => 'windows'

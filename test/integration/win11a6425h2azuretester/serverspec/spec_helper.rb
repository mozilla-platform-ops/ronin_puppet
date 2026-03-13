require 'base64'
require 'serverspec'
require 'winrm'
require 'yaml'

ROOT_DIR = File.expand_path('../../../..', __dir__).freeze
ROLE_NAME = File.basename(File.expand_path('..', __dir__)).freeze
ROLE_DATA = YAML.load_file(File.join(ROOT_DIR, 'data', 'roles', "#{ROLE_NAME}.yaml")).freeze
WINDOWS_DATA = YAML.load_file(File.join(ROOT_DIR, 'data', 'os', 'Windows.yaml')).fetch('windows').freeze
ROLE_HIERA = ROLE_DATA.fetch('win-worker').freeze
VARIANT_DATA = ROLE_HIERA.fetch('variant', {}).freeze
WORKER_FUNCTION = ROLE_HIERA.fetch('function').freeze

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

def deep_fetch(hash, *keys)
  keys.reduce(hash) do |memo, key|
    memo.is_a?(Hash) ? memo[key] : nil
  end
end

def expected_hiera_value(*keys)
  deep_fetch(VARIANT_DATA, *keys) || deep_fetch(WINDOWS_DATA, *keys)
end

def powershell_command(script)
  encoded = Base64.strict_encode64(script.encode('UTF-16LE'))
  command("powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand #{encoded}")
end

def software_property_command(display_name_filter, property)
  powershell_command(<<~POWERSHELL)
    $items = Get-ItemProperty 'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\*', 'HKLM:\\SOFTWARE\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\*' -ErrorAction SilentlyContinue
    $match = $items | Where-Object { #{display_name_filter} } | Select-Object -First 1
    if ($null -eq $match) { exit 1 }
    $match.#{property}
  POWERSHELL
end

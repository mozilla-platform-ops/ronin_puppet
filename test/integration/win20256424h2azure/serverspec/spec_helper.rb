require 'base64'
require 'serverspec'
require 'winrm'

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

def powershell_command(script)
  encoded = Base64.strict_encode64(script.encode('UTF-16LE'))
  command("powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand #{encoded}")
end

def registry_value_command(path, property)
  powershell_command(<<~POWERSHELL)
    $value = Get-ItemPropertyValue -Path '#{path}' -Name '#{property}' -ErrorAction Stop
    $value
  POWERSHELL
end

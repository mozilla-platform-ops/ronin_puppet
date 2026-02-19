require 'serverspec'
require 'winrm'

conn = WinRM::Connection.new(
  endpoint: "http://#{ENV['KITCHEN_HOSTNAME']}:5985/wsman",
  user: ENV['KITCHEN_USERNAME'],
  password: ENV['KITCHEN_PASSWORD'],
  transport: :plaintext,
  basic_auth_only: true,
  operation_timeout: 300,
  receive_timeout: 310
)

Specinfra.configuration.winrm = conn
set :backend, :winrm
set :os, :family => 'windows'

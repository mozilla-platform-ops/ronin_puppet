require 'serverspec'
require 'winrm'

set :backend, :winrm
set :os, :family => 'windows'

require_relative 'spec_helper'

expected_mozilla_build_version = expected_hiera_value('mozilla_build', 'version')
expected_psutil_version = expected_hiera_value('mozilla_build', 'psutil_version')
expected_zstandard_version = expected_hiera_value('mozilla_build', 'zstandard_version')
expected_pip_version = expected_hiera_value('mozilla_build', 'py3_pip_version')

describe file('C:\\mozilla-build') do
  it { should exist }
  it { should be_directory }
end

describe file('C:\\mozilla-build\\msys2\\usr\\bin\\sh.exe') do
  it { should exist }
end

describe powershell_command("Get-Content 'C:\\mozilla-build\\VERSION'") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^#{Regexp.escape(expected_mozilla_build_version)}\s*$/) }
end

describe file('C:\\mozilla-build\\python3\\Lib\\site-packages\\certifi\\cacert.pem') do
  it { should exist }
end

describe file('C:\\mozilla-build\\python3\\Lib\\site-packages\\psutil\\__init__.py') do
  it { should exist }
end

describe powershell_command("& 'C:\\mozilla-build\\python3\\python.exe' -m pip show psutil | Select-String '^Version:' | ForEach-Object { $_.ToString().Split(':', 2)[1].Trim() }") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^#{Regexp.escape(expected_psutil_version)}\s*$/) }
end

describe powershell_command("& 'C:\\mozilla-build\\python3\\python.exe' -m pip show zstandard | Select-String '^Version:' | ForEach-Object { $_.ToString().Split(':', 2)[1].Trim() }") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^#{Regexp.escape(expected_zstandard_version)}\s*$/) }
end

describe powershell_command("& 'C:\\mozilla-build\\python3\\python.exe' -m pip show pip | Select-String '^Version:' | ForEach-Object { $_.ToString().Split(':', 2)[1].Trim() }") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^#{Regexp.escape(expected_pip_version)}\s*$/) }
end

describe file('C:\\builds\\tooltool_cache') do
  it { should exist }
  it { should be_directory }
end

describe powershell_command("[Environment]::GetEnvironmentVariable('TOOLTOOL_CACHE', 'Machine')") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^C:\\builds\\tooltool_cache\s*$/i) }
end

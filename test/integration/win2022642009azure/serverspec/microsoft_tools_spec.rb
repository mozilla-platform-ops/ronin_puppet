require_relative 'spec_helper'

ronin_dir = 'C:\\ProgramData\\PuppetLabs\\ronin'
dxsdk_dir = 'C:\\Program Files (x86)\\Microsoft DirectX SDK (June 2010)'

describe software_property_command("$_.DisplayName -like 'WPTx64*'", 'DisplayName') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^WPTx64/i) }
end

describe file("#{ronin_dir}\\mozprofilerprobe.mof") do
  it { should exist }
end

describe powershell_command("(Get-WindowsOptionalFeature -Online -FeatureName 'NetFx3' -ErrorAction Stop).State") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^Enabled\s*$/i) }
end

describe machine_env_command('DXSDK_DIR') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^#{Regexp.escape(dxsdk_dir)}\s*$/) }
end

describe file("#{dxsdk_dir}\\Include\\audiodefs.h") do
  it { should exist }
end

describe software_property_command("$_.DisplayName -eq 'Microsoft BinScope 2014'", 'DisplayVersion') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^7\.0\.7000\.0\s*$/) }
end

describe software_property_command("$_.DisplayName -eq 'Microsoft Visual C++ 2015 Redistributable (x86) - 14.0.23918'", 'DisplayVersion') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^14\.0\.23918(?:\.0)?\s*$/) }
end

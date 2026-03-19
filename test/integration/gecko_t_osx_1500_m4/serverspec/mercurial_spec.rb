require_relative 'spec_helper'

describe file('/usr/local/bin/hg') do
  it { should exist }
  it { should be_symlink }
  it { should be_linked_to '/Library/Frameworks/Python.framework/Versions/3.11/bin/hg' }
end

describe file('/etc/paths.d/python3.11') do
  it { should exist }
  its(:content) { should match(%r{/Library/Frameworks/Python\.framework/Versions/3\.11/bin}) }
end

describe command('/Library/Frameworks/Python.framework/Versions/3.11/bin/hg --version') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/6\.4\.5/) }
end

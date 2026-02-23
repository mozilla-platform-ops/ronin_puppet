require_relative 'spec_helper'

describe file('/usr/local/bin/tcc_perms.sh') do
  it { should exist }
  it { should be_file }
  it { should be_mode 755 }
end

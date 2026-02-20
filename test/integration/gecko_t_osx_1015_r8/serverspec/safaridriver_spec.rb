require_relative 'spec_helper'

describe 'Safari driver scripts deployed' do
  describe file('/usr/local/bin/add_tcc_perms.sh') do
    it { should exist }
    it { should be_file }
    it { should be_mode 755 }
  end

  describe file('/usr/local/bin/safari-enable-remote-automation.sh') do
    it { should exist }
    it { should be_file }
    it { should be_mode 755 }
  end

  describe file('/usr/local/bin/install_safari_softwareupdate_updates.py') do
    it { should exist }
    it { should be_file }
    it { should be_mode 755 }
  end
end

describe user('cltbld') do
  it { should belong_to_group '_webdeveloper' }
end

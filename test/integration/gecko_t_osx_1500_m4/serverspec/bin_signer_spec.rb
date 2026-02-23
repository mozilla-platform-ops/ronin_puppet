require_relative 'spec_helper'

describe 'start-worker binary is codesigned' do
  describe command('codesign --verify /usr/local/bin/start-worker') do
    its(:exit_status) { should eq 0 }
  end
end

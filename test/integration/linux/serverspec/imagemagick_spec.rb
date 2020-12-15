require_relative 'spec_helper'

# 6.x
describe package('imagemagick'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

# 7.x
describe command('/usr/local/bin/magick --version') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /ImageMagick 7/ }
end

require_relative 'spec_helper'

describe package('imagemagick'), :if => os[:family] == 'ubuntu' do
  it { should be_installed }
end

describe command('/usr/local/bin/magick --version') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /ImageMagick 7/ }
end

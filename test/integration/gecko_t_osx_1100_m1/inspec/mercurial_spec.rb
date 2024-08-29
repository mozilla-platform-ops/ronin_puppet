describe command('pip3 list | grep mercurial') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /mercurial/ }
end

# check version
describe command('hg --version') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match /version 6.4.5/ }
end

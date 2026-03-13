require_relative 'spec_helper'

git_exe = 'C:\\Program Files\\Git\\bin\\git.exe'

describe file(git_exe) do
  it { should exist }
end

describe powershell_command("& '#{git_exe}' --version") do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^git version /i) }
end

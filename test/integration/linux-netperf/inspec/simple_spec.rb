# see http://inspec.io/ or http://inspec.io/ for more info on inspec tests

describe dir('/tmp') do
  it { should exist }
end

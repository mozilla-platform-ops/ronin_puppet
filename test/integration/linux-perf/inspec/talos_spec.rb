require_relative 'spec_helper'

# directories

describe file('/builds') do
  it { should be_directory }
end

describe file('/builds/slave') do
  it { should be_directory }
end

describe file('/builds/slave/talos-data') do
  it { should be_directory }
end

describe file('/builds/slave/talos-data/talos') do
  it { should be_directory }
end

describe file('/builds/git-shared') do
  it { should be_directory }
end

describe file('/builds/hg-shared') do
  it { should be_directory }
end

describe file('/builds/tooltool_cache') do
  it { should be_directory }
end

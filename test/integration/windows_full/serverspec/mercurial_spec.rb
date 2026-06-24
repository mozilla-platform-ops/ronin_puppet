require_relative 'spec_helper'

describe file('C:\\Program Files\\Mercurial\\hg.exe') do
  it { should exist }
end

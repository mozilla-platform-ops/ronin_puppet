require_relative 'spec_helper'

describe file('/usr/local/bin/generic-worker-multiuser') do
    it { should exist }
end

describe file('/usr/local/bin/generic-worker-simple') do
    it { should exist }
end

describe file('/usr/local/bin/start-worker') do
    it { should exist }
end

describe file('/usr/local/bin/taskcluster-proxy') do
    it { should exist }
end

describe file('/usr/local/bin/livelog') do
    it { should exist }
end

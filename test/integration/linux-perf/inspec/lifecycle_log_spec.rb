require_relative 'spec_helper'

describe file('/usr/local/bin/lifecycle-log') do
  it { should exist }
  it { should be_executable }
  it { should be_owned_by 'root' }
  it { should be_grouped_into 'root' }
end

describe file('/var/log/host-lifecycle') do
  it { should exist }
  it { should be_directory }
  it { should be_owned_by 'root' }
  it { should be_grouped_into 'cltbld' }
  its('mode') { should cmp '0775' }
end

describe file('/var/log/host-lifecycle/events.jsonl') do
  it { should exist }
  it { should be_owned_by 'root' }
  it { should be_grouped_into 'cltbld' }
  its('mode') { should cmp '0664' }
end

describe file('/etc/logrotate.d/host-lifecycle') do
  it { should exist }
  its('content') { should match %r{/var/log/host-lifecycle/events\.jsonl} }
  its('content') { should match /^\s*size 1M$/ }
  its('content') { should match /^\s*rotate 39$/ }
  its('content') { should match /^\s*compress$/ }
end

describe file('/etc/sudoers') do
  its('content') do
    should match %r{^cltbld ALL=\(root\) NOPASSWD: /usr/local/bin/lifecycle-log import-generic-worker$}
  end
end

describe file('/usr/local/bin/run-puppet.sh') do
  its('content') { should match /lifecycle_log observe-boot/ }
  its('content') { should match /lifecycle_log emit puppet_run_started/ }
  its('content') { should match /lifecycle_log emit puppet_run_succeeded/ }
end

describe file('/usr/local/bin/run-start-worker.sh') do
  its('content') { should match /lifecycle_log emit worker_started/ }
  its('content') { should match /lifecycle_log import-generic-worker/ }
  its('content') { should match /lifecycle_log emit worker_exited --exit-code/ }
  its('content') { should match /lifecycle_log emit restart_executed --trigger post_task/ }
end

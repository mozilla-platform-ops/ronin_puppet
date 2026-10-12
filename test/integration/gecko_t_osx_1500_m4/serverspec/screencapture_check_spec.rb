require_relative 'spec_helper'

describe file('/usr/local/bin/check-screencapture-grant.sh') do
  it { should exist }
  it { should be_file }
  it { should be_mode 755 }
  it { should be_owned_by 'root' }
end

describe command('/usr/bin/shellcheck --version') do
  # Only assert the script parses; shellcheck itself is a CI concern, not a host one.
  its(:exit_status) { should be_between(0, 127) }
end

describe command('/bin/bash -n /usr/local/bin/check-screencapture-grant.sh') do
  its(:exit_status) { should eq 0 }
end

# The detector must never be able to wedge a worker. worker-runner.sh runs
# run-puppet.sh synchronously before starting the worker and retries the whole
# apply on any "^Error:", so a resource that can fail here takes the host out of
# service entirely rather than merely leaving it without the grant. The exec is
# written as `<script> || true` for exactly that reason -- assert the shape, so a
# future edit that drops the guard is caught here rather than on the fleet.
describe file('/usr/local/bin/check-screencapture-grant.sh') do
  its(:content) { should match(/kTCCServiceScreenCapture/) }
  # System DB only: a user-database row is never consulted by TCC for this service
  # and must not be read as a grant.
  its(:content) { should match(%r{/Library/Application Support/com\.apple\.TCC/TCC\.db}) }
  its(:content) { should_not match(%r{/Users/\w+/Library/Application Support/com\.apple\.TCC}) }
  # flags 12 is an MDM-managed row that TCC ignores; treating it as granted would
  # report a broken host as healthy.
  its(:content) { should match(/2\/12/) }
  # /bin/bash is the failure-screenshot LaunchAgent. Without its grant every
  # screenshot is wallpaper-only and nothing errors, so it must be checked like the
  # worker binaries (RELOPS-2454).
  its(:content) { should match(%r{^CLIENTS=\([^)]*^\s*/bin/bash\s*$[^)]*\)}m) }
end

# Running it is read-only and safe on any host, including under test-kitchen where
# there is no TCC database -- it reports "absent" and exits 1 rather than erroring.
describe command('SCREENCAPTURE_STATUS_FILE=/tmp/sc-grant-spec.json /usr/local/bin/check-screencapture-grant.sh') do
  its(:exit_status) { should be_between(0, 1) }
end

describe command('/usr/bin/python3 -c "import json;d=json.load(open(\'/tmp/sc-grant-spec.json\'));print(d[\'schema\'],d[\'status\'])"') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^1 (granted|not-granted)$/) }
end

# The status file must report /bin/bash alongside the worker binaries, so a host
# whose screenshots are blank shows up in the JSON rather than reading healthy.
describe command('/usr/bin/python3 -c "import json;print(\' \'.join(c[\'client\'] for c in json.load(open(\'/tmp/sc-grant-spec.json\'))[\'clients\']))"') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(%r{/usr/local/bin/generic-worker-multiuser}) }
  its(:stdout) { should match(%r{/usr/local/bin/start-worker}) }
  its(:stdout) { should match(%r{/bin/bash}) }
end

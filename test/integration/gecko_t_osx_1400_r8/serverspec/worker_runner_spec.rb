require_relative 'spec_helper'

WORKER_RUNNER_SH = '/usr/local/bin/worker-runner.sh'.freeze

# Bug 2072152: these testers clear Firefox's Metal shader caches at every worker
# start. The role opts in via the top-level `purge_metal_shader_cache` hiera key, so
# this suite is also what catches that key being moved under `worker:`, where
# secrets/vault.yaml's own `worker:` hash would shadow it and compile the feature
# out without failing anything.
describe file(WORKER_RUNNER_SH) do
  it { should exist }
  it { should be_file }
  it { should be_mode 755 }

  # This role runs the simple engine, so worker-runner.sh is already the task user
  # and its own cache dir is the one tasks use -- no sudo indirection.
  its(:content) { should match(%r{^metal_cache_root=\$\(/usr/bin/getconf DARWIN_USER_CACHE_DIR}) }

  # The glob must cover every org.mozilla.* bundle, not just org.mozilla.firefox:
  # ANGLE compiles in the GPU process, which caches under org.mozilla.*-gpu-helper.
  its(:content) { should match(%r{org\.mozilla\.\*/com\.apple\.metal}) }
end

# Regression guard for the shape of this cleanup, which has been reverted once
# already. #775 walked every user's cache dir as the non-admin task user, which
# logged Permission denied for each dir it did not own and slowed worker startup;
# #922 removed it. Anything that reintroduces a traversal of /private/var/folders is
# that same bug.
#
# Asserted against executable lines only. The script documents both reverted
# attempts by quoting the find invocations they used, and an earlier version of this
# guard matched that prose rather than any running command. What must hold is that no
# such traversal actually executes, not that the history goes unmentioned.
describe "#{WORKER_RUNNER_SH} executable lines" do
  subject(:code) do
    file(WORKER_RUNNER_SH).content
        .lines
        .reject { |line| line.strip.empty? || line.strip.start_with?('#') }
        .join
  end

  # Positive control. A content read that silently returned nothing -- which is how
  # this backend reports an unreadable file -- would leave the traversal assertion
  # below passing vacuously.
  it 'reads the rendered script' do
    expect(code).to match(/^metal_cache_root=/)
  end

  it 'does not traverse /private/var/folders to find caches' do
    expect(code).not_to match(%r{find\s+/private/var/folders})
  end
end

require_relative 'spec_helper'

# Bug 2072152: these testers clear Firefox's Metal shader caches at every worker
# start. The role opts in via the top-level `purge_metal_shader_cache` hiera key, so
# this suite is also what catches that key being moved under `worker:`, where
# secrets/vault.yaml's own `worker:` hash would shadow it and compile the feature
# out without failing anything.
describe file('/usr/local/bin/worker-runner.sh') do
  it { should exist }
  it { should be_file }
  it { should be_mode 755 }

  # This role runs the simple engine, so worker-runner.sh is already the task user
  # and its own cache dir is the one tasks use -- no sudo indirection.
  its(:content) { should match(%r{^metal_cache_root=\$\(/usr/bin/getconf DARWIN_USER_CACHE_DIR}) }

  # The glob must cover every org.mozilla.* bundle, not just org.mozilla.firefox:
  # ANGLE compiles in the GPU process, which caches under org.mozilla.*-gpu-helper.
  its(:content) { should match(%r{org\.mozilla\.\*/com\.apple\.metal}) }

  # Regression guard for the shape of this cleanup, which has been reverted once
  # already. #775 walked every user's cache dir as the non-admin task user, which
  # logged Permission denied for each dir it did not own and slowed worker startup;
  # #922 removed it. Anything that reintroduces a traversal of /private/var/folders
  # to find org.mozilla caches is that same bug.
  its(:content) { should_not match(%r{-path\s+'\*/C/org\.mozilla}) }
end

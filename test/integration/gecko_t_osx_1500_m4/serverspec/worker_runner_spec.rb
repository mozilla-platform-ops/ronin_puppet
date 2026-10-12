require_relative 'spec_helper'

WORKER_RUNNER_SH = '/usr/local/bin/worker-runner.sh'.freeze

# Bug 2046807: the task user persists across tasks on this role, so its Firefox
# Application Support is cleared before every task. Opted in via the top-level
# `purge_firefox_app_support` key, so this also catches the key being shadowed by
# vault's `worker:` hash, which would compile the purge out without failing anything.
describe file(WORKER_RUNNER_SH) do
  it { should exist }
  its(:content) { should match(%r{^ff_app_support="/Users/cltbld/Library/Application Support/Firefox"$}) }
end

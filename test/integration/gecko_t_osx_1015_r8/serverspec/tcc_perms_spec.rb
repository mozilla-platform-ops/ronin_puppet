require_relative 'spec_helper'

# This test suite checks for the presence of a specific entry in the TCC.db using the /usr/bin/sqlite3 binary
describe 'TCC.db' do
  let(:db_path) { '/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db' }
  let(:query) do
    "SELECT * FROM access WHERE service = 'kTCCServiceAppleEvents' AND client = '/usr/libexec/sshd-keygen-wrapper' AND auth_value = 1 AND auth_reason = 1 AND auth_version = 1 AND policy_id IS NULL AND indirect_object_identifier = 'com.apple.systemevents';"
  end

  it 'contains the expected access entry' do
    command = "/usr/bin/sqlite3 '#{db_path}' \"#{query}\""
    result = command(command)

    expect(result.exit_status).to eq(0)
    expect(result.stdout.strip).not_to be_empty
  end
end

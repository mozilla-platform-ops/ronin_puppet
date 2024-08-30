require_relative 'spec_helper'
require 'sqlite3'

# This test suite checks for the presence of a specific entry in the TCC.db
describe 'TCC.db' do
  let(:db_path) { '/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db' }
  let(:query) do
    "SELECT * FROM access WHERE service = 'kTCCServiceAppleEvents' AND client = '/usr/libexec/sshd-keygen-wrapper' AND auth_value = 1 AND auth_reason = 1 AND auth_version = 1 AND policy_id IS NULL AND indirect_object_identifier = 'com.apple.systemevents';"
  end

  it 'contains the expected access entry' do
    db = SQLite3::Database.open(db_path)
    result = db.execute(query)
    db.close

    expect(result).not_to be_empty
    expect(result[0]).to include(
      'kTCCServiceAppleEvents',
      '/usr/libexec/sshd-keygen-wrapper',
      1,
      1,
      1,
      nil,
      'com.apple.systemevents'
    )
  end
end

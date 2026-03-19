require_relative 'spec_helper'

# This test suite checks for the presence, properties, and contents of the pip.conf file.
# It ensures that the file exists, that each user has read access, and that the file contains
# the expected configuration settings.
describe file('/Library/Application Support/pip/pip.conf') do
  it { should exist }

  # Check that the file is readable by all users
  it { should be_readable.by('others') }
  it { should be_readable.by('group') }
  it { should be_readable.by('owner') }

  # Check the contents of the file
  its(:content) { should match /\[install\]\nno-index = true\ndisable-pip-version-check = true\nfind-links =\n    https:\/\/pypi\.pub\.build\.mozilla\.org\/pub\/\ntrusted-host =\n    pypi\.pub\.build\.mozilla\.org\n/ }
  its(:content) { should match /\[global\]\ndisable-pip-version-check = true/ }
end

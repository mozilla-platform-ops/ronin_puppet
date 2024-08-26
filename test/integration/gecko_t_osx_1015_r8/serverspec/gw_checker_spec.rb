require_relative 'spec_helper'

describe command('crontab -l -u root') do
  its(:stdout) { should match(%r{^*/30 \* \* \* \* /usr/local/bin/gw_checker.sh$}) }
end

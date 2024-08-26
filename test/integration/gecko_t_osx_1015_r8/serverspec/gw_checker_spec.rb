require_relative 'spec_helper'

describe crontab('root') do
  its(:content) { should match(%r{^*/30 \* \* \* \* /usr/local/bin/gw_checker.sh$}) }
end

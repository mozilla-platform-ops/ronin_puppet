require_relative 'spec_helper'

role = ENV.fetch('PUPPET_ROLE')
tests = RoninKitchenWindows.pester_tests_for(role)

RSpec.describe "Windows Pester suites for #{role}" do
  tests.each do |test_file|
    context test_file do
      subject(:pester_result) do
        command(RoninKitchenWindows.pester_command(role: role, test_file: test_file))
      end

      its(:exit_status) { should eq 0 }
    end
  end
end

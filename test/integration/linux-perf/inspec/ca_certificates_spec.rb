require_relative 'spec_helper'

if os.family == 'ubuntu' && os.release == '24.04'
  {
    'ca-certificates' => '20260816ubuntu0.24.04.1',
    'libnss3' => '2:3.98-1ubuntu0.3'
  }.each do |name, minimum_version|
    describe package(name) do
      it { should be_installed }
    end

    # Use dpkg so epochs and Ubuntu revisions follow Debian ordering.
    describe command("dpkg --compare-versions \"$(dpkg-query --show --showformat='${Version}' #{name})\" ge '#{minimum_version}'") do
      its('exit_status') { should eq 0 }
    end
  end
end

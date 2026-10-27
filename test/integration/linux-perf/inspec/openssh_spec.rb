require_relative 'spec_helper'

if os.family == 'ubuntu' && os.release == '24.04'
  %w[openssh-client openssh-server openssh-sftp-server].each do |name|
    describe package(name) do
      it { should be_installed }
    end

    # Include the epoch and compare Ubuntu revisions using Debian ordering.
    describe command("dpkg --compare-versions \"$(dpkg-query --show --showformat='${Version}' #{name})\" ge '1:9.6p1-3ubuntu13.20'") do
      its('exit_status') { should eq 0 }
    end
  end
end

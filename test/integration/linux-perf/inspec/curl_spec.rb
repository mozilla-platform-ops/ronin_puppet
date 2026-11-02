require_relative 'spec_helper'

if os.family == 'ubuntu' && os.release == '24.04'
  %w[curl libcurl4t64 libcurl3t64-gnutls].each do |name|
    describe package(name) do
      it { should be_installed }
    end

    # Compare Ubuntu revisions using Debian ordering.
    describe command("dpkg --compare-versions \"$(dpkg-query --show --showformat='${Version}' #{name})\" ge '8.5.0-2ubuntu10.16'") do
      its('exit_status') { should eq 0 }
    end
  end
end

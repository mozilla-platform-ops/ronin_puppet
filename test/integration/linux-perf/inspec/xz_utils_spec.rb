require_relative 'spec_helper'

if os.family == 'ubuntu' && os.release == '24.04'
  %w[xz-utils liblzma5].each do |name|
    describe package(name) do
      it { should be_installed }
    end

    # Compare Ubuntu revisions using Debian version ordering.
    describe command("dpkg --compare-versions \"$(dpkg-query --show --showformat='${Version}' #{name})\" ge '5.6.1+really5.4.5-1ubuntu0.4'") do
      its('exit_status') { should eq 0 }
    end
  end
end

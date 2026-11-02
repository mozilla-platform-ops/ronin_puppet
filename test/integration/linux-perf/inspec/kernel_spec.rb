require_relative 'spec_helper'

if os.family == 'ubuntu' && os.release == '24.04'
  %w[linux-generic linux-image-generic linux-headers-generic].each do |name|
    describe package(name) do
      it { should be_installed }
    end

    describe command("dpkg --compare-versions \"$(dpkg-query --show --showformat='${Version}' #{name})\" ge '6.8.0-147.147'") do
      its('exit_status') { should eq 0 }
    end
  end

  # Kitchen containers share their host kernel. Verify the running kernel and
  # DKMS modules on real workers as part of rp-eqt.6.
end

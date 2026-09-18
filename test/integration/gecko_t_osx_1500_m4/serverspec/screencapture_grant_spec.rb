require_relative 'spec_helper'

# macos_screencapture_grant only manages anything where SIP is enabled -- on a
# SIP-off host macos_tcc_perms writes the ScreenCapture grant into the system
# TCC database directly and this module is deliberately a complete no-op. The
# suite therefore has to branch the same way the manifest does, otherwise it
# fails on whichever kind of host it does not happen to be running on.
sip_enabled = !command('/usr/bin/csrutil status').stdout.match?(/disabled/i)

if sip_enabled
  describe file('/usr/local/bin/approve-screencapture.applescript') do
    it { should exist }
    it { should be_file }
    it { should be_mode 755 }
  end

  describe file('/usr/local/bin/check-screencapture-grant.sh') do
    it { should exist }
    it { should be_file }
    it { should be_mode 755 }
  end

  # The LaunchAgent only ships outside test-kitchen (it lands in cltbld's home,
  # which a kitchen runner has no guarantee of having built out), so these
  # assertions are conditional on that directory being present rather than
  # unconditional -- otherwise the suite fails on the very runner CI uses.
  launchagent = '/Users/cltbld/Library/LaunchAgents/com.mozilla.screencapture.approve.plist'

  if file('/Users/cltbld/Library/LaunchAgents').directory?
    describe file(launchagent) do
      it { should exist }
      it { should be_file }
      it { should be_mode 644 }
      it { should be_owned_by 'cltbld' }
      it { should be_grouped_into 'staff' }

      # The LaunchAgent is useless if its label and the manifest's launchctl
      # bootstrap/kickstart target ever drift apart: launchctl would bootstrap a
      # job puppet then never kickstarts, so the grant would only appear on the
      # next login rather than on the puppet run that asked for it.
      its(:content) { should match(/com\.mozilla\.screencapture\.approve/) }
      its(:content) { should match(%r{/usr/local/bin/approve-screencapture\.applescript}) }
    end

    describe command("/usr/bin/plutil -lint #{launchagent}") do
      its(:exit_status) { should eq 0 }
    end
  end

  describe command('/usr/bin/osacompile -o /dev/null /usr/local/bin/approve-screencapture.applescript') do
    its(:exit_status) { should eq 0 }
  end

else
  describe 'macos_screencapture_grant on a SIP-off host' do
    # Asserted as absent rather than skipped: deploying the GUI approval flow
    # where it is not needed would drive System Settings on a host that runs
    # screen-pixel tests.
    describe file('/usr/local/bin/approve-screencapture.applescript') do
      it { should_not exist }
    end
  end
end

# lib/facter/sip_enabled.rb
#
# System Integrity Protection state. Needed because the ScreenCapture TCC grant
# is obtained two completely different ways depending on it: SIP-off hosts get a
# direct sqlite3 write into the system TCC database (macos_tcc_perms), SIP-on
# hosts cannot write that database at all and have to be granted through the
# Screen Recording pane of System Settings (this module).
Facter.add('sip_enabled') do
  confine kernel: 'Darwin'
  setcode do
    output = Facter::Core::Execution.execute('/usr/bin/csrutil status', on_fail: nil)
    # Absent or unreadable csrutil means we cannot prove SIP is off, and the
    # safe default is to treat the host as SIP-on: this module is a no-op on a
    # host that already has the grant, whereas wrongly assuming SIP-off would
    # silently skip the only path that works.
    output.nil? || !output.match?(/disabled/i)
  end
end

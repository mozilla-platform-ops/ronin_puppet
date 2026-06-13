# Custom fact: cltbld_tcc_db_present
#
# True when /Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db
# exists. The user TCC.db is only created after cltbld has logged in via a
# console session, so on a freshly-bootstrapped worker (autologin set up by
# puppet but cltbld hasn't actually logged in yet) the file is absent.
#
# Used by macos_tcc_perms and macos_safaridriver to gate resources that
# write to cltbld's TCC.db, replacing the older log-grep reboot trigger
# in run-puppet.sh that relied on Apple's error string remaining stable.
Facter.add('cltbld_tcc_db_present') do
  confine kernel: 'Darwin'
  setcode do
    File.exist?('/Users/cltbld/Library/Application Support/com.apple.TCC/TCC.db')
  end
end

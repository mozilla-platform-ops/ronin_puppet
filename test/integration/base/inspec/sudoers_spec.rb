describe file('/etc/sudoers') do
  its(:content) { should include 'cltbld ALL=(root) NOPASSWD: /bin/hahah2222' }
  its(:content) { should include 'cltbld ALL=(root) NOPASSWD: /sbin/reboot' }
end

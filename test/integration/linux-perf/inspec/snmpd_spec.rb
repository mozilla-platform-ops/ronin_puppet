# ensure package is installed
describe package('snmpd') do
    it { should be_installed }
end

describe service('snmpd') do
    it { should be_running }
    it { should be_enabled }
end

# check our templating worked
describe file('/etc/snmp/snmpd.conf') do
    it { should exist }
    its(:owner) { should eq 'root' }
    its(:group) { should eq 'Debian-snmp' }
    its(:mode) { should cmp '0640' }
    # TODO: don't check community secret (so it could work on prod hosts)
    its(:content) { should match /rocommunity aaaa/ }

    # check that our template is in place (and not the default)
    its(:content) { should match /# mozilla relops snmpd.conf template/ }
    # check that RO community is enabled
    its(:content) { should match /^rocommunity/ }
end

describe command('runuser -u cltbld -- test -r /etc/snmp/snmpd.conf') do
    its(:exit_status) { should eq 1 }
end

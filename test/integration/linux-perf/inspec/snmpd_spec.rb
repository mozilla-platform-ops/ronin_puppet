# ensure package is installed
describe package('snmpd') do
    it { should be_installed }
    it { should be_running }
end

# check our templating worked
describe file('/etc/snmp/snmpd.conf') do
    it { should exist }
    its(:content) { should match /rocommunity aaaa/ }
end

require 'puppet'
Puppet.initialize_settings
Puppet[:strict] = :warning
root = File.expand_path('..', __dir__)
Puppet[:modulepath] = [File.join(root, 'modules'), File.join(root, 'r10k_modules')].join(':')
Puppet[:code] = <<~PP
class bitbar_devicepool::systemd_reload {}
include bitbar_devicepool::systemd_reload

user { 'bitbar': ensure => present }
include bitbar_devicepool::devicepool
include bitbar_devicepool::worker_health
include bitbar_devicepool::last_started_alert
PP
facts = {'os'=>{'name'=>'Ubuntu','release'=>{'full'=>'22.04'}}}
node = Puppet::Node.new('test', facts: Puppet::Node::Facts.new('test', facts))
node.environment = Puppet::Node::Environment.create(:test, Puppet[:modulepath].split(':'))
catalog = Puppet::Parser::Compiler.compile(node)
units = %w[bitbar bitbar-v3 bitbar-slack_alert bitbar-influx_logger bitbar-last_started_alert]
units.each do |name|
  unit = catalog.resources.find { |r| r.type == 'File' && r.title == "/etc/systemd/system/#{name}.service" }
  raise "unsafe source for #{name}" unless unit[:source] == "puppet:///modules/bitbar_devicepool/systemd/#{name}.service"
  raise "unsafe permissions for #{name}" unless unit[:owner] == 'root' && unit[:group] == 'root' && unit[:mode] == '0644'
  content = File.read(File.join(root, 'modules/bitbar_devicepool/files/systemd', "#{name}.service"))
  raise "service must run unprivileged: #{name}" unless content.lines.grep(/^User=/) == ["User=bitbar\n"]
end
puts 'PASS: all five units use root-controlled sources and run as bitbar'

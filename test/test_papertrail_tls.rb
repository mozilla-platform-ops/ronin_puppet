# Run with the repository's Puppet Ruby environment; compiles only, never applies.
require 'puppet'
Puppet.initialize_settings
root = File.expand_path('..', __dir__)
paths = %w[modules r10k_modules].map { |p| File.join(root, p) }
Puppet[:modulepath] = paths.join(':')
%w[18.04 22.04 24.04].each do |release|
  [[], ['example']].each_with_index do |identifiers, index|
    Puppet[:code] = <<~PP
      class { 'linux_papertrail':
        papertrail_host => 'logs.example.org',
        papertrail_port => 12345,
        syslog_identifiers => #{identifiers.inspect},
      }
    PP
    facts = {'os' => {'name' => 'Ubuntu', 'release' => {'full' => release}}}
    node = Puppet::Node.new('test', facts: Puppet::Node::Facts.new('test', facts))
    node.environment = Puppet::Node::Environment.create("test#{release.delete('.')}#{index}".to_sym, paths)
    catalog = Puppet::Parser::Compiler.compile(node)
    services = ['papertrail'] + (identifiers.empty? ? [] : ['papertrail-syslog'])
    package = release == '18.04' ? 'nmap' : 'ncat'
    services.each do |name|
      unit = catalog.resources.find { |r| r.type == 'File' && r.title == "/etc/systemd/system/#{name}.service" }
      raise 'missing TLS verification' unless unit[:content].include?('ncat --ssl-verify --ssl-trustfile /etc/papertrail-bundle.pem logs.example.org 12345')
      service = catalog.resources.find { |r| r.type == 'Service' && r.title == name }
      dependencies = Array(service[:require]).map(&:to_s)
      raise 'missing ncat dependency' unless dependencies.include?("Package[#{package}]")
      raise 'missing CA dependency' unless dependencies.include?('File[/etc/papertrail-bundle.pem]')
    end
    bundle = catalog.resources.find { |r| r.type == 'File' && r.title == '/etc/papertrail-bundle.pem' }
    raise 'unsafe CA bundle' unless bundle[:owner] == 'root' && bundle[:mode] == '0644'
    services.each do |name|
      raise "missing CA restart notification: #{bundle[:notify].inspect} for #{name}" unless [bundle[:notify]].flatten.map(&:to_s).include?("Service[#{name}]")
    end
  end
end
puts 'PASS: both logging paths, three OS versions, TLS verification and dependency ordering'

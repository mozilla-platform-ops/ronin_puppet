require 'puppet'
Puppet.initialize_settings
root = File.expand_path('..', __dir__)
Puppet[:modulepath] = [File.join(root, 'modules'), File.join(root, 'r10k_modules')].join(':')
Puppet[:code] = <<~PP
class { 'packages::setup': default_bucket => 'test', default_s3_domain => 'example.org' }
packages::linux_package_from_s3_multi { 'test':
 packages_and_checksums => {'one_1_all.deb' => '#{'a' * 64}', 'two_1_all.deb' => '#{'b' * 64}'},
 temp_dir => '/var/cache/ronin-package-staging/test',
}
packages::linux_package_from_s3 { 'three_1_all.deb': type => 'deb', checksum => '#{'c' * 64}' }
PP
facts = {'os'=>{'name'=>'Ubuntu','distro'=>{'release'=>{'major'=>'24.04'}}}}
node = Puppet::Node.new('test', facts: Puppet::Node::Facts.new('test', facts))
node.environment = Puppet::Node::Environment.create(:test, Puppet[:modulepath].split(':'))
catalog = Puppet::Parser::Compiler.compile(node)
resources = catalog.resources
exec = resources.find { |r| r.type == 'Exec' && r.title == 'install package at /var/cache/ronin-package-staging/test' }
paths = %w[one_1_all.deb two_1_all.deb].map { |f| "/var/cache/ronin-package-staging/test/#{f}" }
raise 'install must name every archive explicitly' unless exec[:command] == ['/usr/bin/apt', 'install', '-f', '-y'] + paths
raise 'guard must be a single argv command' unless exec[:unless] == [['/var/cache/ronin-package-staging/debs-installed'] + paths]
paths.each do |path|
  file = resources.find { |r| r.type == 'File' && r[:path] == path }
  raise 'archive must be root owned and private' unless file[:owner] == 'root' && file[:mode] == '0600'
end
requires = Array(exec[:require]).map(&:to_s)
%w[one_1_all.deb two_1_all.deb].each do |name|
  raise "missing ordering for #{name}" unless requires.include?("File[#{name}]")
end
stage = resources.find { |r| r.type == 'File' && r.title == '/var/cache/ronin-package-staging' }
raise 'staging must be private' unless stage[:owner] == 'root' && stage[:mode] == '0700'
puts 'PASS: explicit install inputs, argv guard, all-file ordering, protected staging'

require 'puppet'
require 'tempfile'
require 'open3'
Puppet.initialize_settings
root = File.expand_path('..', __dir__)
paths = %w[modules r10k_modules].map { |p| File.join(root, p) }
Puppet[:modulepath] = paths.join(':')
[nil, false, 'true', true].each_with_index do |kitchen, index|
  Puppet[:code] = 'include sudo'
  facts = {'os' => {'name' => 'Ubuntu', 'family' => 'Debian'}}
  facts['running_in_test_kitchen'] = kitchen unless kitchen.nil?
  node = Puppet::Node.new('test', facts: Puppet::Node::Facts.new('test', facts))
  node.environment = Puppet::Node::Environment.create("test#{index}".to_sym, paths)
  catalog = Puppet::Parser::Compiler.compile(node)
  fragments = catalog.resources.select { |r| r.type == 'Concat::Fragment' }
  text = fragments.map { |r| r[:content] }.join
  [/^kitchen\s+ALL=.*NOPASSWD: ALL$/, /^%vagrant\s+ALL=.*NOPASSWD: ALL$/].each do |grant|
    raise "incorrect test sudo grants for fact #{kitchen.inspect}" unless text.match?(grant) == (kitchen == true)
  end
  raise 'lost production relops access' unless text.match?(/^relops\s+ALL=/)
  Tempfile.create('ronin-sudoers-test') do |file|
    file.write(text)
    file.flush
    _, error, status = Open3.capture3('/usr/sbin/visudo', '-c', '-f', file.path)
    raise "invalid sudoers: #{error}" unless status.success?
  end
end
puts 'PASS: production omits test grants; only boolean Kitchen fact enables them; relops access retained'

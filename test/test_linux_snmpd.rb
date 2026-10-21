#!/usr/bin/env ruby
# Compile only, with fixture Hiera data; never apply or load production secrets.
require 'tmpdir'
require 'fileutils'
require 'puppet'

repo_root = File.expand_path('..', __dir__)
Dir.mktmpdir('linux-snmpd-test-') do |tmp|
  environment_dir = File.join(tmp, 'environments', 'production')
  FileUtils.mkdir_p(environment_dir)
  Puppet.initialize_settings([
    '--confdir', tmp, '--vardir', tmp, '--logdir', tmp,
    '--environmentpath', File.join(tmp, 'environments'),
    '--hiera_config', File.join(tmp, 'hiera.yaml')
  ])
  File.write(File.join(tmp, 'hiera.yaml'), <<~YAML)
    version: 5
    defaults:
      datadir: .
      data_hash: yaml_data
    hierarchy:
      - name: fixture
        path: fixture.yaml
  YAML
  FileUtils.cp(File.join(tmp, 'hiera.yaml'), File.join(environment_dir, 'hiera.yaml'))
  File.write(File.join(environment_dir, 'fixture.yaml'), "snmpd:\n  ro_community: fixture-community\n")
  File.write(File.join(environment_dir, 'environment.conf'), "modulepath = #{File.join(repo_root, 'modules')}\n")
  FileUtils.mkdir_p(File.join(environment_dir, 'manifests'))
  manifest = File.join(environment_dir, 'manifests', 'site.pp')
  File.write(manifest, "include shared\ninclude linux_snmpd\n")
  %w[18.04 22.04 24.04].each do |release|
    environment = Puppet.lookup(:environments).get(:production)
    facts = Puppet::Node::Facts.new('test.example.com', {
      'os' => { 'name' => 'Ubuntu', 'release' => { 'full' => release } }
    })
    node = Puppet::Node.new('test.example.com', environment: environment, facts: facts)
    catalog = Puppet::Parser::Compiler.compile(node)
    config = catalog.resource('File', '/etc/snmp/snmpd.conf')
    raise 'unsafe config permissions' unless config[:owner] == 'root' && config[:group] == 'Debian-snmp' && config[:mode] == '0640'
    raise 'config diffs disclose the community' unless config[:show_diff] == false
    raise 'config must follow package/group creation' unless config[:require].to_s.downcase.include?('linux_packages::snmpd')
    raise 'config must refresh the daemon' unless config[:notify].to_s.downcase.include?('snmpd')
    raise 'community/template changed' unless config[:content].include?('rocommunity fixture-community default -V all')
    raise 'package missing' unless catalog.resource('Package', 'snmpd')
    raise 'daemon not running' unless catalog.resource('Service', 'snmpd')[:ensure].to_s == 'running'
    %w[snmp_check_gw.sh snmp_worker_pool_id.sh].each do |script|
      raise 'monitoring helper permissions changed' unless catalog.resource('File', "/usr/local/bin/#{script}")[:mode] == '0755'
    end
    puts "Passed: Ubuntu #{release} SNMP catalog protections and monitoring settings"
  end
end

#!/usr/bin/env ruby
# Compile with fixture facts; exercise guards without applying packages or services.
require 'tmpdir'
require 'open3'
require 'rbconfig'
require 'shellwords'
require 'puppet'

def check(condition, message)
  raise message unless condition
end

repo_root = File.expand_path('..', __dir__)
Dir.mktmpdir('linux-openssh-test-') do |tmp|
  Puppet.initialize_settings([
    '--confdir', tmp, '--vardir', tmp, '--logdir', tmp,
    '--hiera_config', File.join(tmp, 'hiera.yaml')
  ])
  File.write(File.join(tmp, 'hiera.yaml'), "version: 5\nhierarchy: []\n")
  manifest = File.join(tmp, 'site.pp')
  # Compile the real base profile, isolating unrelated services and secrets.
  dependencies = %w[
    roles_profiles::profiles::relops_users roles_profiles::profiles::users
    roles_profiles::profiles::sudo roles_profiles::profiles::locale
    roles_profiles::profiles::timezone roles_profiles::profiles::ntp
    roles_profiles::profiles::motd roles_profiles::profiles::securitize
    disable_services grub linux_packages::testresources linux_snmpd
    linux_packages::ca_certificates linux_packages::xz_utils
  ]
  File.write(manifest, dependencies.map { |name| "class #{name} {}\n" }.join +
    "include roles_profiles::profiles::linux_base\n")

  names = %w[openssh-client openssh-server openssh-sftp-server]
  catalog = nil
  %w[18.04 22.04 24.04].each do |release|
    environment = Puppet::Node::Environment.create(:production, [File.join(repo_root, 'modules')], manifest)
    facts = Puppet::Node::Facts.new('test.example.com', {
      'os' => { 'name' => 'Ubuntu', 'release' => { 'full' => release } }
    })
    compiled = Puppet::Parser::Compiler.compile(
      Puppet::Node.new('test.example.com', environment: environment, facts: facts)
    )
    names.each do |name|
      check(!compiled.resource('Package', name).nil? == (release == '24.04'),
        "#{name} must be managed only on Ubuntu 24.04")
    end
    check(!compiled.resource('Exec', 'apt_update_for_openssh').nil? == (release == '24.04'),
      'APT refresh must be limited to Ubuntu 24.04')
    check(compiled.resources.none? { |resource| resource.type == 'Service' },
      'package remediation must not change SSH service/socket activation')
    catalog = compiled if release == '24.04'
    puts "Passed: Ubuntu #{release} OpenSSH profile scope and activation configuration"
  end

  old = '1:9.6p1-3ubuntu13.14'
  fixed = '1:9.6p1-3ubuntu13.20'
  newer = '1:9.6p1-3ubuntu13.21'
  ral = catalog.to_ral
  graph = ral.relationship_graph
  names.each do |name|
    package = ral.resource('Package', name)
    check(package[:provider] == :apt && package[:ensure] == ">=#{fixed}", "wrong enforcement for #{name}")
    [[:absent, false], [old, false], [fixed, true], [newer, true], ['9.9p1-1', false]].each do |version, expected|
      check(package.provider.insync?(version) == expected, "#{name} version #{version} acceptance")
    end
    check(graph.edges.any? { |edge|
      edge.source.ref == 'Exec[apt_update_for_openssh]' && edge.target.ref == "Package[#{name}]"
    }, "APT refresh must precede #{name}")
  end
  puts 'Passed: OpenSSH minimum/newer versions, Debian epoch and APT refresh ordering'

  # Substitute fixture executables on macOS, retaining the compiled shell guard.
  query = File.join(tmp, 'dpkg-query')
  File.write(query, <<~'RUBY')
    abort 'unexpected dpkg-query arguments' unless ARGV[0..1] == ['--show', '--showformat=${Version}']
    key = {
      'openssh-client' => 'SSH_TEST_CLIENT', 'openssh-server' => 'SSH_TEST_SERVER',
      'openssh-sftp-server' => 'SSH_TEST_SFTP'
    }.fetch(ARGV.last)
    version = ENV.fetch(key)
    exit 1 if version.empty?
    print version
  RUBY
  compare = File.join(tmp, 'dpkg')
  File.write(compare, <<~'RUBY')
    require 'puppet'
    require 'puppet/util/package/version/debian'
    abort 'unexpected dpkg arguments' unless ARGV[0] == '--compare-versions' && ARGV[2] == 'ge'
    exit 1 if ARGV[1].empty?
    debian = Puppet::Util::Package::Version::Debian
    exit(debian.parse(ARGV[1]) >= debian.parse(ARGV[3]) ? 0 : 1)
  RUBY
  refresh = catalog.resource('Exec', 'apt_update_for_openssh')
  check(refresh[:command] == '/usr/bin/apt-get update', 'wrong APT refresh command')
  guard = refresh[:unless].gsub('/usr/bin/dpkg-query', Shellwords.join([RbConfig.ruby, query]))
    .gsub('/usr/bin/dpkg', Shellwords.join([RbConfig.ruby, compare]))
  scenarios = [[fixed, fixed, fixed], [newer, newer, newer], [old, old, old], ['', '', '']]
  names.each_index do |index|
    [old, newer, '', '9.9p1-1'].each do |version|
      scenario = [fixed, fixed, fixed]
      scenario[index] = version
      scenarios << scenario
    end
  end
  scenarios.each do |versions|
    skip_refresh = versions.all? { |version| [fixed, newer].include?(version) }
    output, status = Open3.capture2e(
      %w[SSH_TEST_CLIENT SSH_TEST_SERVER SSH_TEST_SFTP].zip(versions).to_h, '/bin/sh', '-c', guard
    )
    check(status.success? == skip_refresh, "wrong refresh guard result for #{versions.inspect}: #{output}")
  end
  puts "Passed: all #{scenarios.length} OpenSSH refresh scenarios, including each package independently"
end

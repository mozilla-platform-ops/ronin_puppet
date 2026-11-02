#!/usr/bin/env ruby
# Compile with fixture facts and exercise guards without applying resources.
require 'tmpdir'
require 'open3'
require 'rbconfig'
require 'shellwords'
require 'puppet'

def check(condition, message)
  raise message unless condition
end

repo_root = File.expand_path('..', __dir__)
Dir.mktmpdir('linux-ca-certificates-test-') do |tmp|
  Puppet.initialize_settings([
    '--confdir', tmp, '--vardir', tmp, '--logdir', tmp,
    '--hiera_config', File.join(tmp, 'hiera.yaml')
  ])
  File.write(File.join(tmp, 'hiera.yaml'), "version: 5\nhierarchy: []\n")
  manifest = File.join(tmp, 'site.pp')
  # Isolate the real linux_base profile from unrelated services and Hiera data.
  dependencies = %w[
    roles_profiles::profiles::relops_users roles_profiles::profiles::users
    roles_profiles::profiles::sudo roles_profiles::profiles::locale
    roles_profiles::profiles::timezone roles_profiles::profiles::ntp
    roles_profiles::profiles::motd roles_profiles::profiles::securitize
    disable_services grub linux_packages::testresources linux_snmpd
  ]
  File.write(manifest, dependencies.map { |name| "class #{name} {}\n" }.join +
    "include roles_profiles::profiles::linux_base\n")

  catalog = nil
  %w[18.04 22.04 24.04].each do |release|
    environment = Puppet::Node::Environment.create(
      :production, [File.join(repo_root, 'modules')], manifest
    )
    facts = Puppet::Node::Facts.new('test.example.com', {
      'os' => { 'name' => 'Ubuntu', 'release' => { 'full' => release } }
    })
    node = Puppet::Node.new('test.example.com', environment: environment, facts: facts)
    compiled = Puppet::Parser::Compiler.compile(node)
    %w[ca-certificates libnss3].each do |name|
      check(!compiled.resource('Package', name).nil? == (release == '24.04'),
        "#{name} must be managed only on Ubuntu 24.04")
    end
    check(!compiled.resource('Exec', 'apt_update_for_ca_certificates').nil? == (release == '24.04'),
      'APT refresh must be limited to Ubuntu 24.04')
    catalog = compiled if release == '24.04'
    puts "Passed: Ubuntu #{release} profile scope"
  end

  ral = catalog.to_ral
  graph = ral.relationship_graph
  versions = {
    'ca-certificates' => ['20240203', '20260816ubuntu0.24.04.1', '20260816ubuntu0.24.04.2'],
    'libnss3' => ['2:3.98-1ubuntu0.2', '2:3.98-1ubuntu0.3', '2:3.98-1ubuntu0.4']
  }
  versions.each do |name, (old, fixed, newer)|
    package = ral.resource('Package', name)
    check(package[:provider] == :apt, "#{name} must use Debian version comparisons")
    check(package[:ensure] == ">=#{fixed}", "wrong minimum version for #{name}")
    [[:absent, false], [old, false], [fixed, true], [newer, true]].each do |version, expected|
      check(package.provider.insync?(version) == expected, "#{name} version #{version} acceptance")
    end
    check(graph.edges.any? { |edge|
      edge.source.ref == 'Exec[apt_update_for_ca_certificates]' && edge.target.ref == "Package[#{name}]"
    }, "APT refresh must precede #{name}")
  end
  check(!ral.resource('Package', 'libnss3').provider.insync?('1:99.0-1'), 'NSS epoch must be respected')
  puts 'Passed: minimum versions, newer versions, Debian epoch and refresh ordering'

  # macOS has no dpkg. Substitute fixture executables; retain the compiled shell
  # expression and use Puppet's Debian comparator for their version checks.
  query = File.join(tmp, 'dpkg-query')
  File.write(query, <<~'RUBY')
    abort 'unexpected dpkg-query arguments' unless ARGV[0..1] == ['--show', '--showformat=${Version}']
    version = ENV.fetch(ARGV.last == 'ca-certificates' ? 'CA_TEST_VERSION' : 'NSS_TEST_VERSION')
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
  refresh = catalog.resource('Exec', 'apt_update_for_ca_certificates')
  check(refresh[:command] == '/usr/bin/apt-get update', 'wrong APT refresh command')
  guard = refresh[:unless].gsub('/usr/bin/dpkg-query', Shellwords.join([RbConfig.ruby, query]))
    .gsub('/usr/bin/dpkg', Shellwords.join([RbConfig.ruby, compare]))
  ca_old, ca_fixed, ca_new = versions.fetch('ca-certificates')
  nss_old, nss_fixed, nss_new = versions.fetch('libnss3')
  [
    [ca_old, nss_old, false], [ca_old, nss_fixed, false], [ca_fixed, nss_old, false],
    [ca_fixed, nss_fixed, true], [ca_new, nss_fixed, true], [ca_fixed, nss_new, true],
    [ca_new, nss_new, true], ['', nss_fixed, false], [ca_fixed, '', false],
    [ca_fixed, '1:99.0-1', false]
  ].each do |ca_version, nss_version, skip_refresh|
    output, status = Open3.capture2e(
      { 'CA_TEST_VERSION' => ca_version, 'NSS_TEST_VERSION' => nss_version }, '/bin/sh', '-c', guard
    )
    check(status.success? == skip_refresh,
      "wrong refresh guard result for CA=#{ca_version.inspect}, NSS=#{nss_version.inspect}: #{output}")
  end
  puts 'Passed: APT refresh guard for outdated, fixed, newer and missing packages'
end

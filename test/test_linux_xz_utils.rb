#!/usr/bin/env ruby
# Compile with fixture facts; exercise guards without applying packages.
require 'tmpdir'
require 'open3'
require 'rbconfig'
require 'shellwords'
require 'puppet'

def check(condition, message)
  raise message unless condition
end

repo_root = File.expand_path('..', __dir__)
Dir.mktmpdir('linux-xz-utils-test-') do |tmp|
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
    linux_packages::ca_certificates
  ]
  File.write(manifest, dependencies.map { |name| "class #{name} {}\n" }.join +
    "include roles_profiles::profiles::linux_base\n")

  catalog = nil
  %w[18.04 22.04 24.04].each do |release|
    environment = Puppet::Node::Environment.create(:production, [File.join(repo_root, 'modules')], manifest)
    facts = Puppet::Node::Facts.new('test.example.com', {
      'os' => { 'name' => 'Ubuntu', 'release' => { 'full' => release } }
    })
    compiled = Puppet::Parser::Compiler.compile(
      Puppet::Node.new('test.example.com', environment: environment, facts: facts)
    )
    %w[xz-utils liblzma5].each do |name|
      check(!compiled.resource('Package', name).nil? == (release == '24.04'),
        "#{name} must be managed only on Ubuntu 24.04")
    end
    check(!compiled.resource('Exec', 'apt_update_for_xz_utils').nil? == (release == '24.04'),
      'APT refresh must be limited to Ubuntu 24.04')
    check(!compiled.resource('Package', 'xzdec'), 'do not install the optional xzdec package')
    catalog = compiled if release == '24.04'
    puts "Passed: Ubuntu #{release} XZ profile scope"
  end

  old = '5.6.1+really5.4.5-1ubuntu0.2'
  fixed = '5.6.1+really5.4.5-1ubuntu0.4'
  newer = '5.6.1+really5.4.5-1ubuntu0.5'
  ral = catalog.to_ral
  graph = ral.relationship_graph
  %w[xz-utils liblzma5].each do |name|
    package = ral.resource('Package', name)
    check(package[:provider] == :apt && package[:ensure] == ">=#{fixed}", "wrong enforcement for #{name}")
    [[:absent, false], [old, false], [fixed, true], [newer, true]].each do |version, expected|
      check(package.provider.insync?(version) == expected, "#{name} version #{version} acceptance")
    end
    check(graph.edges.any? { |edge|
      edge.source.ref == 'Exec[apt_update_for_xz_utils]' && edge.target.ref == "Package[#{name}]"
    }, "APT refresh must precede #{name}")
  end
  puts 'Passed: XZ minimum/newer versions and APT refresh ordering'

  # Substitute fixture executables on macOS, retaining the compiled shell guard.
  query = File.join(tmp, 'dpkg-query')
  File.write(query, <<~'RUBY')
    abort 'unexpected dpkg-query arguments' unless ARGV[0..1] == ['--show', '--showformat=${Version}']
    key = { 'xz-utils' => 'XZ_TEST_VERSION', 'liblzma5' => 'LZMA_TEST_VERSION' }.fetch(ARGV.last)
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
  refresh = catalog.resource('Exec', 'apt_update_for_xz_utils')
  check(refresh[:command] == '/usr/bin/apt-get update', 'wrong APT refresh command')
  guard = refresh[:unless].gsub('/usr/bin/dpkg-query', Shellwords.join([RbConfig.ruby, query]))
    .gsub('/usr/bin/dpkg', Shellwords.join([RbConfig.ruby, compare]))
  [old, fixed, newer, ''].product([old, fixed, newer, '']).each do |xz_version, lzma_version|
    skip_refresh = [fixed, newer].include?(xz_version) && [fixed, newer].include?(lzma_version)
    output, status = Open3.capture2e(
      { 'XZ_TEST_VERSION' => xz_version, 'LZMA_TEST_VERSION' => lzma_version }, '/bin/sh', '-c', guard
    )
    check(status.success? == skip_refresh,
      "wrong refresh guard result for XZ=#{xz_version.inspect}, liblzma=#{lzma_version.inspect}: #{output}")
  end
  puts 'Passed: all 16 combinations of outdated, fixed, newer and missing XZ packages'
end

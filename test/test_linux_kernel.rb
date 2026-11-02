#!/usr/bin/env ruby
# Compile and exercise the refresh guard without installing kernels or rebooting.
require 'tmpdir'
require 'open3'
require 'rbconfig'
require 'shellwords'
require 'puppet'

def check(condition, message)
  raise message unless condition
end

repo_root = File.expand_path('..', __dir__)
Dir.mktmpdir('linux-kernel-test-') do |tmp|
  Puppet.initialize_settings([
    '--confdir', tmp, '--vardir', tmp, '--logdir', tmp,
    '--hiera_config', File.join(tmp, 'hiera.yaml')
  ])
  File.write(File.join(tmp, 'hiera.yaml'), "version: 5\nhierarchy: []\n")
  manifest = File.join(tmp, 'site.pp')
  dependencies = %w[nodejs xvfb llvm sox libxcb1 gstreamer git ia32libs]
  File.write(manifest, dependencies.map { |name| "class linux_packages::#{name} {}\n" }.join +
    "Package { provider => apt }\ninclude linux_talos\n")

  catalog = nil
  %w[18.04 22.04 24.04].each do |release|
    environment = Puppet::Node::Environment.create(:production, [File.join(repo_root, 'modules')], manifest)
    facts = Puppet::Node::Facts.new('test.example.com', {
      'os' => { 'name' => 'Ubuntu', 'release' => { 'full' => release } },
      'running_in_test_kitchen' => 'true'
    })
    compiled = Puppet::Parser::Compiler.compile(
      Puppet::Node.new('test.example.com', environment: environment, facts: facts)
    )
    check(compiled.resource('Package', 'linux-generic')[:ensure].to_s == 'latest',
      'keep the existing generic kernel update policy')
    check(compiled.resource('Package', 'v4l2loopback-dkms')[:ensure].to_s == 'latest',
      'keep DKMS package management')
    check(!compiled.resource('Exec', 'apt_update_for_linux_generic').nil? == (release == '24.04'),
      'kernel metadata refresh must be limited to Ubuntu 24.04')
    # This change should not add another kernel flavor or automatic reboot.
    kernel_packages = compiled.resources.select { |resource|
      resource.type == 'Package' && resource.title.start_with?('linux-')
    }
    check(kernel_packages.map(&:title) == ['linux-generic'], 'unexpected kernel package/flavor change')
    check(compiled.resources.none? { |resource|
      resource.type == 'Exec' && resource[:command].match?(/\breboot\b|\bshutdown\b/)
    }, 'kernel remediation must not introduce automatic reboots')
    catalog = compiled if release == '24.04'
    puts "Passed: Ubuntu #{release} kernel policy, scope and DKMS catalog"
  end

  graph = catalog.to_ral.relationship_graph
  check(graph.edges.any? { |edge|
    edge.source.ref == 'Exec[apt_update_for_linux_generic]' && edge.target.ref == 'Package[linux-generic]'
  }, 'refresh APT before checking/installing the latest kernel')

  query = File.join(tmp, 'dpkg-query')
  File.write(query, <<~'RUBY')
    abort 'unexpected query arguments' unless ARGV == ['--show', '--showformat=${Version}', 'linux-generic']
    version = ENV.fetch('KERNEL_TEST_VERSION')
    exit 1 if version.empty?
    print version
  RUBY
  compare = File.join(tmp, 'dpkg')
  File.write(compare, <<~'RUBY')
    require 'puppet'
    require 'puppet/util/package/version/debian'
    abort 'unexpected comparison arguments' unless ARGV[0] == '--compare-versions' && ARGV[2..] == ['ge', '6.8.0-147.147']
    exit 1 if ARGV[1].empty?
    debian = Puppet::Util::Package::Version::Debian
    exit(debian.parse(ARGV[1]) >= debian.parse(ARGV[3]) ? 0 : 1)
  RUBY
  refresh = catalog.resource('Exec', 'apt_update_for_linux_generic')
  check(refresh[:command] == '/usr/bin/apt-get update', 'wrong metadata refresh command')
  guard = refresh[:unless].gsub('/usr/bin/dpkg-query', Shellwords.join([RbConfig.ruby, query]))
    .gsub('/usr/bin/dpkg', Shellwords.join([RbConfig.ruby, compare]))
  {
    '' => false,
    '6.8.0-99.99' => false,
    '6.8.0-146.146' => false,
    '6.8.0-147.147~test1' => false,
    '6.8.0-147.147' => true,
    '6.8.0-148.148' => true
  }.each do |version, skip_refresh|
    output, status = Open3.capture2e({ 'KERNEL_TEST_VERSION' => version }, '/bin/sh', '-c', guard)
    check(status.success? == skip_refresh, "wrong kernel refresh guard result for #{version.inspect}: #{output}")
  end
  puts 'Passed: refresh ordering and missing/old/prerelease/fixed/newer kernel versions'
end

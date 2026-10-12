#!/usr/bin/env ruby
# Compile only, with fixture facts; never apply resources or use secrets.
require 'tmpdir'
require 'puppet'

repo_root = File.expand_path('..', __dir__)
$LOAD_PATH.unshift(File.join(repo_root, 'r10k_modules', 'archive', 'lib'))
require 'puppet/type/archive'

Dir.mktmpdir('linux-caddy-test-') do |tmp|
  Puppet.initialize_settings([
    '--confdir', tmp, '--vardir', tmp, '--logdir', tmp,
    '--hiera_config', File.join(tmp, 'hiera.yaml')
  ])
  File.write(File.join(tmp, 'hiera.yaml'), "version: 5\nhierarchy: []\n")
  manifest = File.join(tmp, 'site.pp')
  File.write(manifest, <<~PUPPET)
    # Use Linux package defaults even when the compiler runs on macOS.
    Package { provider => apt }
    include linux_packages::caddy
    include linux_packages::xvfb
    exec { 'apt_update': command => '/usr/bin/apt-get update' }
  PUPPET
  %w[18.04 22.04 24.04].each do |release|
    environment = Puppet::Node::Environment.create(
      :production, [File.join(repo_root, 'modules'), File.join(repo_root, 'r10k_modules')], manifest
    )
    facts = Puppet::Node::Facts.new('test.example.com', {
      'os' => { 'name' => 'Ubuntu', 'architecture' => 'amd64', 'release' => { 'full' => release } }
    })
    node = Puppet::Node.new('test.example.com', environment: environment, facts: facts)
    catalog = Puppet::Parser::Compiler.compile(node)
    graph = catalog.to_ral.relationship_graph
    source_file = '/etc/apt/sources.list.d/caddy-stable.list'
    raise 'old source retained' unless catalog.resource('File', source_file)[:ensure].to_s == 'absent'
    raise 'old key retained' unless catalog.resource('File', '/usr/share/keyrings/caddy-stable-archive-keyring.gpg')[:ensure].to_s == 'absent'
    %w[apt-update-xvfb apt_update].each do |title|
      ordered = graph.edges.any? { |edge| edge.source.ref == "File[#{source_file}]" && edge.target.ref == "Exec[#{title}]" }
      raise "source removal must precede #{title}" unless ordered
    end
    cache = catalog.resource('File', '/root/caddy-packages')
    raise 'unsafe package cache' unless cache[:owner] == 'root' && cache[:group] == 'root' && cache[:mode] == '0700'
    path = '/root/caddy-packages/caddy_2.11.7_linux_amd64.deb'
    archive = catalog.resource('Archive', path)
    raise 'wrong package source' unless archive[:source] == 'https://ronin-puppet-package-repo.s3.us-west-2.amazonaws.com/linux/public/common/caddy_2.11.7_linux_amd64.deb'
    raise 'checksum not pinned' unless archive[:checksum_type] == 'sha256' && archive[:checksum] == 'a22b914ffd1958da42bc7ab13b7b62c6100634e0798ab594891d2d61d53ba749'
    raise 'download must follow protected directory creation' unless archive[:require].to_s.include?('/root/caddy-packages')
    package = catalog.resource('Package', 'caddy')
    raise 'package not pinned to source version' unless package[:ensure].to_s == 'latest' && package[:provider].to_s == 'dpkg' && package[:source] == path
    raise 'install must follow verified download' unless package[:require].to_s.include?("Archive[#{path}]")
    raise 'Cloudsmith setup remains' if catalog.resource('Exec', 'add_caddy_repository') || catalog.resource('Exec', 'install_caddy_gpg_key')
    puts "Passed: Ubuntu #{release} Caddy mirror, checksum, pin and APT cleanup ordering"
  end
end

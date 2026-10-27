#!/usr/bin/env ruby
# Compile actual user resources with fixture data; never apply a catalog.
require 'tmpdir'
require 'json'
require 'puppet'

repo = File.expand_path('..', __dir__)
Dir.mktmpdir('bootstrap-access-order-') do |tmp|
  File.write(File.join(tmp, 'hiera.yaml'), "version: 5\ndefaults:\n  datadir: .\nhierarchy:\n  - name: fixture\n    path: data.json\n    data_hash: json_data\n")
  File.write(File.join(tmp, 'data.json'), JSON.generate({
    'all_users' => { 'aerickson' => ['fixture-admin-key'], 'relops' => ['fixture-shared-key'] },
    'user_groups' => { 'relops' => ['aerickson'] }
  }))
  Puppet.initialize_settings(['--confdir', tmp, '--vardir', tmp, '--logdir', tmp,
                              '--hiera_config', File.join(tmp, 'hiera.yaml')])
  manifest = File.join(tmp, 'site.pp')
  File.write(manifest, <<~PP)
    class users::global {}
    include roles_profiles::profiles::relops_users
    include roles_profiles::profiles::securitize
    Class['roles_profiles::profiles::relops_users'] -> Class['roles_profiles::profiles::securitize']
  PP
  env = Puppet::Node::Environment.create(:production, [File.join(repo, 'modules')], manifest)
  facts = Puppet::Node::Facts.new('test.invalid', { 'os' => { 'name' => 'Ubuntu', 'family' => 'Debian' } })
  node = Puppet::Node.new('test.invalid', environment: env, facts: facts)
  graph = Puppet::Parser::Compiler.compile(node).to_ral.relationship_graph
  edges = graph.edges.map { |edge| [edge.source.ref, edge.target.ref] }
  vertices = graph.vertices.map(&:ref)
  remaining = vertices.dup
  until remaining.empty?
    ready = remaining.reject { |v| edges.any? { |source, target| target == v && remaining.include?(source) } }
    raise 'Dependency cycle in access handoff catalog' if ready.empty?
    remaining -= ready
  end
  pairs = [
    ['File[/home/aerickson/.ssh/authorized_keys]', 'File[/home/relops/.ssh/authorized_keys]'],
    ['File[/home/relops/.ssh/authorized_keys]', 'Exec[remove relops password]'],
    ['Exec[remove relops password]', 'File[/root/.ssh/authorized_keys]']
  ]
  pairs.each do |source, target|
    pending = [source]
    seen = []
    until pending.empty?
      vertex = pending.shift
      next if seen.include?(vertex)
      seen << vertex
      pending.concat(edges.select { |from, _to| from == vertex }.map(&:last))
    end
    raise "Missing access handoff ordering: #{source} -> #{target}" unless seen.include?(target)
  end
  puts 'Passed: personal SSH access precedes installer-key replacement and account lockdown; no catalog cycles'
end

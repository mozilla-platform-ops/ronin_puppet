#!/usr/bin/env ruby
# Compile only: barebones runner must work without pre-existing directories.
require 'tmpdir'
require 'puppet'

repo = File.expand_path('..', __dir__)
Dir.mktmpdir('puppet-run-script-') do |tmp|
  Puppet.initialize_settings(['--confdir', tmp, '--vardir', tmp, '--logdir', tmp])
  manifest = File.join(tmp, 'site.pp')
  File.write(manifest, "include puppet::run_script\n")
  %w[18.04 22.04].each do |release|
    env = Puppet::Node::Environment.create(:production, [File.join(repo, 'modules')], manifest)
    facts = Puppet::Node::Facts.new('test.invalid', {
      'os' => { 'name' => 'Ubuntu', 'release' => { 'full' => release } }
    })
    catalog = Puppet::Parser::Compiler.compile(Puppet::Node.new('test.invalid', environment: env, facts: facts))
    paths = %w[/etc/puppet /etc/puppet/environments /etc/puppet/environments/production /etc/puppet/environments/production/code]
    paths.each do |path|
      resource = catalog.resource('File', path)
      raise "Missing directory #{path}" unless resource && resource[:ensure].to_s == 'directory'
      raise "Unsafe directory #{path}" unless resource[:owner] == 'root' && resource[:group] == 'root' && resource[:mode] == '0755'
    end
    edges = catalog.to_ral.relationship_graph.edges.map { |edge| [edge.source.ref, edge.target.ref] }
    paths.each_cons(2) do |parent, child|
      raise "Missing ordering #{parent} -> #{child}" unless edges.include?(["File[#{parent}]", "File[#{child}]"])
    end
    puts "Passed: Ubuntu #{release} barebones runner creates and orders all checkout parents"
  end
end

#!/usr/bin/env ruby
# Compile catalogs only; never apply resources or use real credentials.
require 'tmpdir'
require 'puppet'

repo_root = File.expand_path('..', __dir__)
telegraf_user = 'F28_SENTINEL_TELEGRAF_USER'
telegraf_password = 'F28_SENTINEL_TELEGRAF_PASSWORD'
slugs = %w[
  mozilla-platform-ops/ronin_puppet
  aerickson/ronin_puppet-private
  mozilla-platform-ops/ronin_puppet-private
].freeze

Dir.mktmpdir('puppet-deploy-keys-') do |tmp|
  Puppet.initialize_settings([
    '--confdir', tmp, '--vardir', tmp, '--logdir', tmp,
    '--hiera_config', File.join(tmp, 'hiera.yaml')
  ])
  File.write(File.join(tmp, 'hiera.yaml'), "version: 5\nhierarchy: []\n")

  cases = {
    'all keys' => slugs.to_h { |slug| [slug, { 'private_key' => "test-key-#{slug}" }] },
    'private forks only' => slugs.drop(1).to_h { |slug| [slug, { 'private_key' => "test-key-#{slug}" }] },
    'empty and missing entries' => { slugs[0] => { 'private_key' => '' }, slugs[1] => {} },
    'no deploy_keys map' => nil
  }

  cases.each do |name, keys|
    code = <<~PUPPET
      class linux_packages::openvox {}
      class linux_packages::yqer {}
      class { 'puppet::atboot':
        telegraf_user     => '#{telegraf_user}',
        telegraf_password => '#{telegraf_password}',
        smtp_relay_host   => 'localhost',
        github_deploy_keys => #{keys ? keys.inspect.gsub('nil', 'undef') : 'undef'},
      }
    PUPPET
    manifest = File.join(tmp, "#{name}.pp")
    File.write(manifest, code)
    environment = Puppet::Node::Environment.create(
      :production, [File.join(repo_root, 'modules'), File.join(repo_root, 'r10k_modules')], manifest
    )
    facts = Puppet::Node::Facts.new('test.example.com', {
      'os' => { 'name' => 'Ubuntu', 'release' => { 'full' => '18.04' } }
    })
    node = Puppet::Node.new('test.example.com', environment: environment, facts: facts)
    catalog = Puppet::Parser::Compiler.compile(node)

    marker_helper = catalog.resource('File', '/usr/local/bin/puppet-run-marker')
    unless marker_helper && marker_helper[:owner] == 'root' && marker_helper[:group] == 'root' && marker_helper[:mode] == '0755'
      raise "#{name}: marker helper is missing or unsafe"
    end

    wrapper = catalog.resource('File', '/usr/local/bin/run-puppet.sh')[:content]
    if [telegraf_user, telegraf_password, 'notify_telegraf'].any? { |value| wrapper.include?(value) }
      raise "#{name}: unused Telegraf credentials or code remain in the Linux wrapper"
    end

    slugs.each do |slug|
      path = "/root/.ssh/#{slug.tr('/-', '__')}_deploy_key"
      resource = catalog.resource('File', path)
      raise "#{name}: missing resource #{path}" unless resource

      key = keys&.dig(slug, 'private_key')
      expected_ensure = key.is_a?(String) && !key.empty? ? 'file' : 'absent'
      raise "#{name}: incorrect ensure for #{path}" unless resource[:ensure].to_s == expected_ensure
      next if expected_ensure == 'absent'

      raise "#{name}: incorrect permissions" unless resource[:owner] == 'root' && resource[:group] == 'root' && resource[:mode] == '0600'
      content = resource[:content]
      raise "#{name}: key is not Sensitive" unless resource.sensitive_parameters.include?(:content)
      raise "#{name}: incorrect key content" unless content == key
      raise "#{name}: key diff enabled" unless resource[:show_diff] == false
    end
    puts "Passed: #{name}"
  end
end

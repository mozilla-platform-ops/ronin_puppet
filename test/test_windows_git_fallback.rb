#!/usr/bin/env ruby
# Compile fixture catalogs only; never install software or apply resources.
require 'tmpdir'
require 'puppet'
require 'open3'

root = File.expand_path('..', __dir__)
module_root = ARGV.fetch(0, File.join(root, 'r10k_modules'))
%w[archive acl].each { |name| $LOAD_PATH.unshift(File.join(module_root, name, 'lib')) }
require 'puppet/type/archive'
require 'puppet/type/acl'

Dir.mktmpdir('windows-git-fallback-') do |tmp|
  dependencies = File.join(tmp, 'modules')
  Dir.mkdir(dependencies)
  %w[archive acl stdlib powershell].each { |name| File.symlink(File.join(module_root, name), File.join(dependencies, name)) }
  Puppet.initialize_settings(['--confdir', tmp, '--vardir', tmp, '--logdir', tmp,
                              '--hiera_config', File.join(tmp, 'hiera.yaml')])
  File.write(File.join(tmp, 'hiera.yaml'), "version: 5\ndefaults:\n  datadir: .\n  data_hash: yaml_data\nhierarchy:\n  - name: fixture\n    path: data.yaml\n")
  manifest = File.join(tmp, 'site.pp')
  File.write(manifest, 'include roles_profiles::profiles::git')
  [
    [nil, 'amd64', '2.49.0', '64-bit', '2.49.0.windows.1'],
    ['0.0.0', 'aarch64', '2.49.0', 'arm64', '2.49.0.windows.1'],
    ['0.0.0', 'amd64', '2.56.0.2', '64-bit', '2.56.0.windows.2'],
    ['2.48.0', 'amd64', '2.49.0', '64-bit', '2.49.0.windows.1'],
    ['2.49.0', 'amd64', '2.49.0', nil, nil],
    ['2.50.0', 'amd64', '2.49.0', nil, nil],
    ['2.56.0', 'amd64', '2.49.0', nil, nil],
    ['2.56.0.1', 'amd64', '2.56.0.2', '64-bit', '2.56.0.windows.2'],
    ['2.56.0.2', 'amd64', '2.56.0.2', nil, nil],
    ['2.56.0.3', 'amd64', '2.56.0.2', nil, nil]
  ].each do |detected, arch, version, suffix, release|
    File.write(File.join(tmp, 'data.yaml'), "windows:\n  git:\n    version: '#{version}'\n")
    environment = Puppet::Node::Environment.create(:production,
      [File.join(root, 'modules'), dependencies], manifest)
    facts = Puppet::Node::Facts.new('test.example.com', {
      'os' => { 'name' => 'Windows' }, 'custom_win_systemdrive' => 'C:',
      'custom_win_git_version' => detected, 'custom_win_os_arch' => arch
    })
    catalog = Puppet::Parser::Compiler.compile(Puppet::Node.new('test.example.com', environment: environment, facts: facts))
    install = catalog.resource('Exec', 'git_minimum_version')
    if suffix
      path = "C:\\RoninPackages\\Git-#{version}-#{suffix}.exe"
      archive = catalog.resource('Archive', 'git_installer')
      raise 'Wrong Git URL' unless archive[:source] == "https://github.com/git-for-windows/git/releases/download/v#{release}/Git-#{version}-#{suffix}.exe"
      raise 'Installer staging is not protected first' unless archive[:require].to_s.downcase.include?('win_packages::staging')
      acl = catalog.resource('Acl', path)
      raise 'Installer ACL missing' unless acl && acl[:inherit_parent_permissions] == false && acl[:purge] == true
      raise 'Download must precede ACL' unless acl[:require].to_s.include?('git_installer')
      raise 'Wrong installer command' unless install && install[:provider].to_s == 'powershell' && install[:command].include?(path)
      raise 'Install must follow ACL' unless install[:require].to_s.include?(path)
      raise 'Silent install options missing' unless install[:command].include?('/VERYSILENT') && install[:command].include?('/NORESTART')
      # Execute the actual guard with mocked detection, including stale catalog facts.
      [nil, '2.48.0', version, '99.0.0'].each do |actual|
        present = actual ? '$true' : '$false'
        script = "function Join-Path { 'mock-git.exe' }; function Test-Path { #{present} }; function Get-Command { [pscustomobject]@{ Version = [version]'#{actual || '0.0.0'}' } }; " + install[:unless]
        output, status = Open3.capture2e('pwsh', '-NoProfile', '-NonInteractive', '-Command', script)
        expected = actual && Puppet::Util::Package.versioncmp(actual, version) >= 0 ? 0 : 1
        raise "Wrong runtime guard for #{actual.inspect}: #{output}" unless status.exitstatus == expected
      end
      [0, 3010, 1603].each do |code|
        script = "function Start-Process { [pscustomobject]@{ ExitCode = #{code} } }; " + install[:command]
        output, status = Open3.capture2e('pwsh', '-NoProfile', '-NonInteractive', '-Command', script)
        raise "Wrong installer exit handling for #{code}: #{output}" unless status.success? == [0, 3010].include?(code)
      end
    else
      raise 'Existing Git should be left alone' if install || catalog.resource('Archive', 'git_installer')
    end
    raise 'Chocolatey returned' if catalog.resources.any? { |resource| resource.ref.match?(/chocolatey/i) }
    puts "Passed: detected=#{detected.inspect}, arch=#{arch}, configured=#{version}"
  end
end

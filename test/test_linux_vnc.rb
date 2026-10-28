#!/usr/bin/env ruby
# Compile only; run password staging with fixture paths and the current uid/gid.
# Real systemd lifecycle and VNC authentication require an on-host canary.
require 'tmpdir'
require 'fileutils'
require 'shellwords'
require 'open3'
require 'puppet'

def check(condition, message)
  raise message unless condition
end

repo_root = File.expand_path('..', __dir__)
Dir.mktmpdir('linux-vnc-test-') do |tmp|
  Puppet.initialize_settings([
    '--confdir', tmp, '--vardir', tmp, '--logdir', tmp,
    '--hiera_config', File.join(tmp, 'hiera.yaml')
  ])
  File.write(File.join(tmp, 'hiera.yaml'), "version: 5\nhierarchy: []\n")

  %w[18.04 22.04 24.04].each do |release|
    manifest = File.join(tmp, "#{release}.pp")
    File.write(manifest, <<~PUPPET)
      class linux_packages::vnc_server {}
      class { 'linux_vnc':
        user => 'vncuser', group => 'vncgroup',
        user_homedir => '/home/vncuser', user_password => 'fixture-password',
      }
    PUPPET
    environment = Puppet::Node::Environment.create(
      :production, [File.join(repo_root, 'modules')], manifest
    )
    facts = Puppet::Node::Facts.new('test.example.com', {
      'os' => { 'name' => 'Ubuntu', 'release' => { 'full' => release } }
    })
    node = Puppet::Node.new('test.example.com', environment: environment, facts: facts)
    catalog = Puppet::Parser::Compiler.compile(node)
    unit = catalog.resource('File', '/lib/systemd/system/x11vnc.service')
    check(unit[:owner] == 'root' && unit[:group] == 'root' && unit[:mode] == '0644', 'unit ownership/mode')
    check(unit[:notify].to_s.include?('reload systemd for x11vnc'), 'unit must notify daemon-reload')
    reload = catalog.resource('Exec', 'reload systemd for x11vnc')
    check(reload[:refreshonly] == true && reload[:command] == '/bin/systemctl daemon-reload', 'reload must be refresh-only')
    check(!catalog.resource('Service', 'x11vnc'), 'VNC must remain manually started')
    source = catalog.resource('File', '/etc/vnc_passwdfile')
    check(source[:owner] == 'root' && source[:group] == 'root' && source[:mode] == '0600' && source[:show_diff] == false, 'source password protections')

    content = unit[:content]
    check(!content.include?('/home/') && !content.include?('rm:') && !content.include?('/bin/chown'), 'privileged home preparation remains')
    settings = content.lines.grep(/^[A-Za-z]+=/).map { |line| line.strip.split('=', 2) }.to_h
    {
      'User' => 'root', 'Group' => 'vncgroup', 'RuntimeDirectory' => 'x11vnc',
      'RuntimeDirectoryMode' => '0710', 'RuntimeDirectoryPreserve' => 'no'
    }.each { |key, value| check(settings[key] == value, "incorrect #{key}") }
    check(settings['ExecStart'].include?('-passwdfile /run/x11vnc/passwdfile'), 'VNC must read runtime password')
    check(settings['ExecStart'].end_with?(' vncuser'), 'VNC must run as configured user')
    command = Shellwords.split(settings.fetch('ExecStartPre'))
    check(command == %w[/usr/bin/install -o root -g vncgroup -m 0640 /etc/vnc_passwdfile /run/x11vnc/passwdfile], 'unexpected staging command')

    fixture = File.join(tmp, release)
    FileUtils.mkdir_p(fixture)
    target = File.join(fixture, 'unrelated-root-file')
    File.write(target, 'must stay unchanged')
    before = File.stat(target)
    home = File.join(fixture, 'home')
    FileUtils.mkdir_p(File.join(home, '.vnc'))
    File.symlink(target, File.join(home, '.vnc', 'passwdfile'))
    runtime = File.join(fixture, 'run', 'x11vnc')
    FileUtils.mkdir_p(runtime)
    File.chmod(0710, runtime)
    password = File.join(fixture, 'source-password')
    File.write(password, 'fixture-password')
    File.chmod(0600, password)
    # Ownership cannot be root in this unprivileged local test. Assert the root
    # arguments above, then exercise the actual install command with our uid/gid.
    local_command = command.dup
    local_command[2] = Process.uid.to_s
    local_command[4] = Process.gid.to_s
    local_command[-2] = password
    local_command[-1] = File.join(runtime, 'passwdfile')
    ['password symlink', 'directory symlink'].each do |attack|
      if attack == 'directory symlink'
        FileUtils.mv(File.join(home, '.vnc'), File.join(fixture, 'attacker-directory'))
        File.symlink(File.join(fixture, 'attacker-directory'), File.join(home, '.vnc'))
      end
      output, status = Open3.capture2e(*local_command)
      check(status.success?, "staging failed: #{output}")
      check(File.read(local_command[-1]) == 'fixture-password', 'password staging failed')
      check((File.stat(local_command[-1]).mode & 0777) == 0640, 'runtime password mode')
      after = File.stat(target)
      check(File.read(target) == 'must stay unchanged' && after.uid == before.uid && after.gid == before.gid && after.mode == before.mode, "#{attack} modified unrelated file")
      check(File.symlink?(File.join(home, '.vnc', 'passwdfile')), 'home password symlink was touched')
    end
    puts "Passed: Ubuntu #{release} catalog, unit settings, password/directory symlink attacks"
  end
end

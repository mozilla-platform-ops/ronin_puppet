#!/opt/puppetlabs/puppet/bin/ruby
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'optparse'
require 'rbconfig'
require 'securerandom'
require 'socket'
require 'time'
require 'timeout'

begin
  require 'puppet'
  require 'facter'
rescue LoadError => e
  warn("Puppet/OpenVox Ruby libraries were not available: #{e.message}")
end

VERSION = '2'

class RoninSbom
  attr_reader :components, :configuration, :errors

  def initialize
    @components = []
    @configuration = []
    @errors = []
    @component_keys = {}
    @configuration_keys = {}
  end

  def error(collector, message)
    @errors << {
      'collector' => collector.to_s,
      'message' => message.to_s,
    }
  end

  def component(name:, version: nil, type: 'application', source: nil, purl: nil, properties: {})
    return if blank?(name)

    key = [
      type,
      name.to_s.downcase,
      version.to_s.downcase,
      source.to_s.downcase,
      properties.fetch('provider', '').to_s.downcase,
    ].join('|')
    return if @component_keys[key]

    @component_keys[key] = true
    record = {
      'type' => type.to_s,
      'name' => name.to_s,
    }
    record['version'] = version.to_s unless blank?(version)
    record['purl'] = purl.to_s unless blank?(purl)

    props = normalize_properties(properties)
    props['source'] = source unless blank?(source)
    record['properties'] = props.sort.map { |k, v| { 'name' => "ronin:#{k}", 'value' => v.to_s } } unless props.empty?
    @components << record
  end

  def config(kind:, name:, source: nil, properties: {})
    return if blank?(name)

    key = [kind, name, source].map { |item| item.to_s.downcase }.join('|')
    return if @configuration_keys[key]

    @configuration_keys[key] = true
    @configuration << {
      'kind' => kind.to_s,
      'name' => name.to_s,
      'source' => source.to_s,
      'properties' => normalize_properties(properties),
    }
  end

  private

  def blank?(value)
    value.nil? || value.to_s.strip.empty?
  end

  def normalize_properties(properties)
    properties.each_with_object({}) do |(key, value), memo|
      next if value.nil? || value.to_s.empty?

      memo[key.to_s] = value.to_s
    end
  end
end

def puppet_available?
  defined?(Puppet) && defined?(Facter)
end

def init_puppet(inv)
  return unless puppet_available?

  Puppet.initialize_settings
  Puppet::Util::Log.newdestination(:console)
rescue StandardError => e
  inv.error('puppet-init', e.message)
end

def fact_value(name)
  return nil unless defined?(Facter)

  value = Facter.value(name)
  value.respond_to?(:to_h) ? value.to_h : value
rescue StandardError
  nil
end

def host_os
  RbConfig::CONFIG['host_os']
end

def windows?
  host_os =~ /mswin|mingw|cygwin/i
end

def macos?
  host_os =~ /darwin/i
end

def linux?
  host_os =~ /linux/i
end

def env_true?(name)
  %w[1 true yes].include?(ENV[name].to_s.downcase)
end

def command(*args, timeout: 60)
  Timeout.timeout(timeout) do
    stdout, stderr, status = Open3.capture3(*args)
    {
      ok: status.success?,
      stdout: stdout,
      stderr: stderr,
      exitstatus: status.exitstatus,
    }
  end
rescue StandardError => e
  {
    ok: false,
    stdout: '',
    stderr: e.message,
    exitstatus: nil,
  }
end

def resource_value(resource, attribute)
  value = resource[attribute]
  return nil if value.nil?

  value.respond_to?(:join) ? value.join(',') : value.to_s
rescue StandardError
  nil
end

def provider_name(resource)
  provider = resource.provider
  return nil unless provider

  if provider.respond_to?(:name)
    provider.name
  elsif provider.class.respond_to?(:name)
    provider.class.name.split('::').last
  end
rescue StandardError
  nil
end

def collect_puppet_type(inv, type_name, timeout: 120)
  type = Puppet::Type.type(type_name)
  return [] unless type

  Timeout.timeout(timeout) { type.instances }
rescue Timeout::Error
  inv.error("puppet-ral-#{type_name}", "collector exceeded #{timeout}s")
  []
rescue StandardError => e
  inv.error("puppet-ral-#{type_name}", e.message)
  []
end

def collect_packages(inv)
  return unless env_true?('RONIN_SBOM_COLLECT_PUPPET_PACKAGES')

  collect_puppet_type(inv, :package, timeout: 120).each do |package|
    name = resource_value(package, :name) || package.title
    ensure_value = resource_value(package, :ensure)
    version = ensure_value unless %w[present installed latest].include?(ensure_value.to_s)
    provider = provider_name(package)
    purl = package_purl(name, version, provider)

    inv.component(
      name: name,
      version: version,
      type: 'application',
      source: 'puppet-ral-package',
      purl: purl,
      properties: {
        provider: provider,
        ensure: ensure_value,
      },
    )
  end
end

def package_purl(name, version, provider)
  return nil if name.nil? || version.nil?

  case provider.to_s
  when /apt|dpkg/
    "pkg:deb/debian/#{name}@#{version}"
  when /yum|dnf|rpm/
    "pkg:rpm/#{name}@#{version}"
  when /gem/
    "pkg:gem/#{name}@#{version}"
  when /pip/
    "pkg:pypi/#{name}@#{version}"
  else
    nil
  end
end

def collect_services(inv)
  collect_puppet_type(inv, :service, timeout: 60).each do |service|
    inv.config(
      kind: 'service',
      name: resource_value(service, :name) || service.title,
      source: 'puppet-ral-service',
      properties: {
        provider: provider_name(service),
        ensure: resource_value(service, :ensure),
        enable: resource_value(service, :enable),
      },
    )
  end
end

def collect_users_and_groups(inv)
  collect_puppet_type(inv, :user, timeout: 60).each do |user|
    inv.config(
      kind: 'user',
      name: resource_value(user, :name) || user.title,
      source: 'puppet-ral-user',
      properties: {
        uid: resource_value(user, :uid),
        gid: resource_value(user, :gid),
        home: resource_value(user, :home),
        shell: resource_value(user, :shell),
        provider: provider_name(user),
      },
    )
  end

  collect_puppet_type(inv, :group, timeout: 60).each do |group|
    inv.config(
      kind: 'group',
      name: resource_value(group, :name) || group.title,
      source: 'puppet-ral-group',
      properties: {
        gid: resource_value(group, :gid),
        provider: provider_name(group),
      },
    )
  end
end

def collect_platform_packages(inv)
  collect_macos_applications(inv) if macos?
  if macos? && env_true?('RONIN_SBOM_COLLECT_DEEP_PACKAGES')
    collect_homebrew(inv)
    collect_pkgutil(inv)
  end
  collect_dpkg(inv) if linux?
  collect_rpm(inv) if linux?
  collect_snap(inv) if linux? && env_true?('RONIN_SBOM_COLLECT_SNAP_PACKAGES')
  collect_windows_package_extras(inv) if windows?
end

def collect_macos_applications(inv)
  [
    '/Applications/*.app',
    '/System/Applications/*.app',
  ].flat_map { |pattern| Dir.glob(pattern) }.each do |path|
    inv.component(
      name: File.basename(path, '.app'),
      type: 'application',
      source: 'macos-application',
      properties: {
        path: path,
      },
    )
  end
end

def collect_homebrew(inv)
  brew = find_command('brew')
  return unless brew

  result = command(brew, 'list', '--versions', timeout: 120)
  unless result[:ok]
    inv.error('homebrew', result[:stderr])
    return
  end

  result[:stdout].each_line do |line|
    name, *versions = line.split
    next if name.nil?

    version = versions.join(',')
    inv.component(
      name: name,
      version: version,
      type: 'application',
      source: 'homebrew',
      purl: version.empty? ? nil : "pkg:brew/#{name}@#{version}",
    )
  end
end

def collect_pkgutil(inv)
  return unless find_command('pkgutil')

  result = command('pkgutil', '--pkgs', timeout: 120)
  unless result[:ok]
    inv.error('macos-pkgutil', result[:stderr])
    return
  end

  result[:stdout].each_line do |line|
    package_id = line.strip
    next if package_id.empty?

    inv.component(
      name: package_id,
      type: 'library',
      source: 'macos-pkgutil',
    )
  end
end

def collect_dpkg(inv)
  dpkg_query = find_command('dpkg-query')
  return unless dpkg_query

  result = command(dpkg_query, '-W', '-f=${binary:Package}\t${Version}\t${Architecture}\n', timeout: 60)
  unless result[:ok]
    inv.error('dpkg', result[:stderr])
    return
  end

  result[:stdout].each_line do |line|
    name, version, architecture = line.chomp.split("\t", 3)
    next if name.nil? || name.empty?

    inv.component(
      name: name,
      version: version,
      type: 'application',
      source: 'dpkg',
      purl: version.to_s.empty? ? nil : "pkg:deb/debian/#{name}@#{version}",
      properties: {
        provider: 'dpkg',
        architecture: architecture,
      },
    )
  end
end

def collect_rpm(inv)
  rpm = find_command('rpm')
  return unless rpm

  result = command(rpm, '-qa', '--qf', "%{NAME}\t%{VERSION}-%{RELEASE}\t%{ARCH}\n", timeout: 60)
  unless result[:ok]
    inv.error('rpm', result[:stderr])
    return
  end

  result[:stdout].each_line do |line|
    name, version, architecture = line.chomp.split("\t", 3)
    next if name.nil? || name.empty?

    inv.component(
      name: name,
      version: version,
      type: 'application',
      source: 'rpm',
      purl: version.to_s.empty? ? nil : "pkg:rpm/#{name}@#{version}",
      properties: {
        provider: 'rpm',
        architecture: architecture,
      },
    )
  end
end

def collect_snap(inv)
  snap = find_command('snap')
  return unless snap

  result = command(snap, 'list', timeout: 120)
  unless result[:ok]
    inv.error('snap', result[:stderr])
    return
  end

  result[:stdout].lines.drop(1).each do |line|
    name, version, = line.split
    next if name.nil?

    inv.component(
      name: name,
      version: version,
      type: 'application',
      source: 'snap',
    )
  end
end

def collect_windows_package_extras(inv)
  powershell = windows_powershell
  return unless powershell

  collect_windows_json(inv, powershell, 'windows-installed-program', <<~'POWERSHELL') do |row|
    $paths = @(
      'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
      'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue |
      Where-Object { $_.DisplayName } |
      Select-Object DisplayName,DisplayVersion,Publisher,InstallDate,PSChildName |
      ConvertTo-Json -Depth 4
  POWERSHELL
    inv.component(
      name: row['DisplayName'],
      version: row['DisplayVersion'],
      type: 'application',
      source: 'windows-installed-program',
      properties: {
        publisher: row['Publisher'],
        install_date: row['InstallDate'],
        registry_key: row['PSChildName'],
      },
    )
  end

  collect_windows_json(inv, powershell, 'windows-hotfix',
                       'Get-HotFix | Select-Object HotFixID,Description,InstalledOn,InstalledBy | ConvertTo-Json -Depth 4') do |row|
    inv.component(
      name: row['HotFixID'],
      version: row['InstalledOn'],
      type: 'application',
      source: 'windows-hotfix',
      properties: {
        description: row['Description'],
        installed_by: row['InstalledBy'],
      },
    )
  end

  collect_windows_json(inv, powershell, 'windows-appx',
                       'Get-AppxPackage -AllUsers | Select-Object Name,Version,Publisher,PackageFullName | ConvertTo-Json -Depth 4') do |row|
    inv.component(
      name: row['Name'],
      version: row['Version'],
      type: 'application',
      source: 'windows-appx',
      properties: {
        publisher: row['Publisher'],
        package_full_name: row['PackageFullName'],
      },
    )
  end

  collect_windows_json(inv, powershell, 'windows-driver',
                       'Get-WindowsDriver -Online -All | Select-Object Driver,Version,ProviderName,ClassName | ConvertTo-Json -Depth 4') do |row|
    inv.component(
      name: row['Driver'],
      version: row['Version'],
      type: 'device-driver',
      source: 'windows-driver',
      properties: {
        provider: row['ProviderName'],
        class: row['ClassName'],
      },
    )
  end
end

def collect_windows_json(inv, powershell, source, script)
  result = command(powershell, '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
                   '-Command', script, timeout: 180)
  unless result[:ok]
    inv.error(source, result[:stderr])
    return
  end

  rows = JSON.parse(result[:stdout])
  rows = [rows] if rows.is_a?(Hash)
  rows.each { |row| yield row if row.is_a?(Hash) }
rescue StandardError => e
  inv.error(source, e.message)
end

def windows_powershell
  candidates = []
  candidates << File.join(ENV['SystemRoot'], 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe') if ENV['SystemRoot']
  candidates << 'powershell.exe'
  candidates.find { |candidate| executable_command?(candidate) }
end

def collect_configuration(inv)
  inv.config(
    kind: 'environment-variable',
    name: 'PATH',
    source: 'process-environment',
    properties: { value: ENV['PATH'] },
  )

  selected_files.each do |path|
    next unless File.exist?(path)

    inv.config(
      kind: File.directory?(path) ? 'directory' : 'file',
      name: path,
      source: 'ronin-managed-path',
      properties: file_evidence(path),
    )
  end

  if windows? || env_true?('RONIN_SBOM_COLLECT_PUPPET_CONFIG')
    collect_services(inv)
    collect_users_and_groups(inv)
  end
end

def selected_files
  if windows?
    [
      'C:/generic-worker/generic-worker.config',
      'C:/generic-worker/task-user-init.cmd',
      'C:/worker-runner/runner.yml',
      'C:/ProgramData/PuppetLabs/ronin',
      'C:/mozilla-build/python3/pip.conf',
    ]
  elsif macos?
    [
      '/opt/puppet_environments/last_run_metadata.json',
      '/opt/puppet_environments/ronin_settings',
      '/etc/puppet_role',
      '/Library/LaunchDaemons/org.mozilla.generic-worker.plist',
      '/Library/LaunchDaemons/org.mozilla.worker-runner.plist',
      '/usr/local/bin/run-generic-worker.sh',
      '/usr/local/bin/run-start-worker.sh',
    ]
  else
    [
      '/etc/puppet/last_run_metadata.json',
      '/etc/puppet/ronin_settings',
      '/etc/systemd/system/generic-worker.service',
      '/etc/systemd/system/worker-runner.service',
      '/etc/generic-worker/generic-worker.config',
      '/etc/snmp/snmpd.conf',
      '/usr/local/bin/run-start-worker.sh',
      '/usr/local/bin/run-generic-worker.sh',
    ]
  end
end

def file_evidence(path)
  stat = File.stat(path)
  evidence = {
    path: path,
    mode: format('%o', stat.mode & 0o7777),
    size: stat.size,
    mtime: stat.mtime.utc.iso8601,
  }
  evidence[:sha256] = Digest::SHA256.file(path).hexdigest if File.file?(path)
  evidence
rescue StandardError => e
  { path: path, error: e.message }
end

def collect_taskcluster_binaries(inv)
  taskcluster_binary_paths.each do |path|
    next unless File.file?(path)

    version = nil
    if env_true?('RONIN_SBOM_COLLECT_BINARY_VERSIONS')
      ['--short-version', '--version', '-version'].each do |flag|
        result = command(path, flag, timeout: 10)
        next unless result[:ok]

        version = first_line(result[:stdout] + result[:stderr])
        break if version
      end
    end

    inv.component(
      name: File.basename(path),
      version: version,
      type: 'application',
      source: 'taskcluster-binary',
      properties: file_evidence(path),
    )
  end
end

def taskcluster_binary_paths
  if windows?
    [
      'C:/generic-worker/generic-worker.exe',
      'C:/generic-worker/taskcluster-proxy.exe',
      'C:/generic-worker/livelog.exe',
      'C:/worker-runner/start-worker.exe',
    ]
  else
    [
      '/usr/local/bin/generic-worker',
      '/usr/local/bin/taskcluster-proxy',
      '/usr/local/bin/start-worker',
      '/usr/local/bin/livelog',
      '/usr/bin/generic-worker',
      '/usr/bin/taskcluster-proxy',
      '/opt/worker/bin/generic-worker',
      '/opt/worker/bin/taskcluster-proxy',
    ]
  end
end

def first_line(text)
  text.each_line.map(&:strip).find { |line| !line.empty? }
end

def metadata(inv)
  facts = {}
  if defined?(Facter)
    %w[
      os kernel architecture networking puppet_role custom_win_worker_pool_id
      custom_win_gw_workerType custom_win_deployment_id custom_win_bootstrap_stage
    ].each do |fact|
      value = fact_value(fact)
      facts[fact] = value unless value.nil? || value.to_s.empty?
    end
  end

  data = {
    generated_at: Time.now.utc.iso8601,
    generator: 'ronin_sbom',
    generator_version: VERSION,
    hostname: Socket.gethostname,
    ruby: RUBY_VERSION,
    ruby_engine: defined?(RUBY_ENGINE) ? RUBY_ENGINE : 'ruby',
    host_os: host_os,
    puppet_version: defined?(Puppet) ? Puppet.version : nil,
    facts: facts,
  }

  data.merge!(puppet_settings)
  data.merge!(ronin_git_metadata(inv))
  data.merge!(last_run_metadata)
  stringify_keys(data)
end

def puppet_settings
  return {} unless defined?(Puppet)

  {
    puppet_confdir: Puppet[:confdir],
    puppet_vardir: Puppet[:vardir],
    puppet_statedir: Puppet[:statedir],
    puppet_lastrunreport: Puppet[:lastrunreport],
    puppet_lastrunfile: Puppet[:lastrunfile],
  }
rescue StandardError
  {}
end

def last_run_metadata
  paths = if windows?
            []
          elsif macos?
            ['/opt/puppet_environments/last_run_metadata.json']
          else
            ['/etc/puppet/last_run_metadata.json']
          end

  paths.each do |path|
    next unless File.file?(path)

    data = JSON.parse(File.read(path))
    return { puppet_run_metadata_file: path, puppet_run_metadata: data }
  rescue StandardError
    next
  end
  {}
end

def ronin_git_metadata(inv)
  repo = ronin_repo_path
  return {} unless repo && File.directory?(File.join(repo, '.git'))

  values = {}
  {
    ronin_git_repo: ['git', '-C', repo, 'config', '--get', 'remote.origin.url'],
    ronin_git_branch: ['git', '-C', repo, 'rev-parse', '--abbrev-ref', 'HEAD'],
    ronin_git_sha: ['git', '-C', repo, 'rev-parse', 'HEAD'],
    ronin_git_status: ['git', '-C', repo, 'status', '--porcelain'],
  }.each do |key, args|
    result = command(*args, timeout: 15)
    if result[:ok]
      values[key] = result[:stdout].strip
    else
      inv.error('ronin-git', result[:stderr])
    end
  end
  values[:ronin_git_dirty] = !values.fetch(:ronin_git_status, '').empty?
  values.delete(:ronin_git_status)
  values
end

def ronin_repo_path
  return 'C:/ronin' if windows? && File.directory?('C:/ronin')

  candidates = [
    '/etc/puppet/environments/mozilla-platform-ops/code',
    '/opt/puppet_environments/*/ronin_puppet',
  ]
  candidates.flat_map { |pattern| Dir.glob(pattern) }.find { |path| File.directory?(File.join(path, '.git')) }
end

def build_cyclonedx(meta, inv)
  {
    'bomFormat' => 'CycloneDX',
    'specVersion' => '1.5',
    'serialNumber' => "urn:uuid:#{SecureRandom.uuid}",
    'version' => 1,
    'metadata' => {
      'timestamp' => meta['generated_at'],
      'tools' => {
        'components' => [
          {
            'type' => 'application',
            'name' => 'ronin_sbom',
            'version' => VERSION,
          },
        ],
      },
      'component' => {
        'type' => 'operating-system',
        'name' => platform_name(meta),
      },
      'properties' => metadata_properties(meta, inv),
    },
    'components' => inv.components.sort_by { |component| [component['name'].downcase, component['version'].to_s] },
  }
end

def platform_name(meta)
  os = meta.dig('facts', 'os')
  if os.is_a?(Hash)
    [os.dig('name'), os.dig('release', 'full')].compact.join(' ')
  else
    meta['host_os']
  end
end

def metadata_properties(meta, inv)
  flat_metadata(meta).map { |key, value| { 'name' => "ronin:#{key}", 'value' => value.to_s } } + [
    { 'name' => 'ronin:component_count', 'value' => inv.components.length.to_s },
    { 'name' => 'ronin:configuration_count', 'value' => inv.configuration.length.to_s },
    { 'name' => 'ronin:collector_error_count', 'value' => inv.errors.length.to_s },
  ]
end

def flat_metadata(meta, prefix = nil)
  meta.each_with_object({}) do |(key, value), memo|
    name = [prefix, key].compact.join('.')
    if value.is_a?(Hash)
      memo.merge!(flat_metadata(value, name))
    elsif value.is_a?(Array)
      memo[name] = value.join(',')
    elsif !value.nil? && !value.to_s.empty?
      memo[name] = value
    end
  end
end

def build_inventory(meta, inv)
  {
    'schema_version' => 2,
    'generated_at' => meta['generated_at'],
    'metadata' => meta,
    'components' => inv.components,
    'configuration' => inv.configuration,
    'collector_errors' => inv.errors,
  }
end

def build_markdown(meta, inv)
  lines = []
  lines << '# Ronin Puppet SBOM'
  lines << ''
  lines << "Generated: `#{escape_md(meta['generated_at'])}`"
  lines << ''
  lines << '## Summary'
  lines << ''
  lines << '| Item | Count |'
  lines << '|------|-------|'
  lines << "| Components | #{inv.components.length} |"
  lines << "| Configuration records | #{inv.configuration.length} |"
  lines << "| Collector errors | #{inv.errors.length} |"
  lines << ''
  lines << '## Metadata'
  lines << ''
  lines << '| Name | Value |'
  lines << '|------|-------|'
  flat_metadata(meta).sort.each do |key, value|
    lines << "| #{escape_md(key)} | #{escape_md(value)} |"
  end
  lines << ''

  inv.components.group_by { |component| source_for(component) }.sort.each do |source, components|
    lines << "## Components: #{escape_md(source)}"
    lines << ''
    lines << '| Name | Version | Type |'
    lines << '|------|---------|------|'
    components.sort_by { |component| component['name'].downcase }.each do |component|
      lines << "| #{escape_md(component['name'])} | #{escape_md(component['version'])} | #{escape_md(component['type'])} |"
    end
    lines << ''
  end

  unless inv.configuration.empty?
    lines << '## Configuration Evidence'
    lines << ''
    lines << '| Kind | Name | Source |'
    lines << '|------|------|--------|'
    inv.configuration.sort_by { |record| [record['kind'], record['name']] }.each do |record|
      lines << "| #{escape_md(record['kind'])} | #{escape_md(record['name'])} | #{escape_md(record['source'])} |"
    end
    lines << ''
  end

  unless inv.errors.empty?
    lines << '## Collector Errors'
    lines << ''
    lines << '| Collector | Message |'
    lines << '|-----------|---------|'
    inv.errors.each do |error|
      lines << "| #{escape_md(error['collector'])} | #{escape_md(error['message'])} |"
    end
    lines << ''
  end

  lines.join("\n") + "\n"
end

def source_for(component)
  prop = Array(component['properties']).find { |item| item['name'] == 'ronin:source' }
  prop ? prop['value'] : 'unknown'
end

def escape_md(value)
  value.to_s.gsub('|', '\\|').gsub(/\r?\n/, ' ')
end

def write_json(path, data)
  tmp = "#{path}.tmp"
  File.write(tmp, JSON.pretty_generate(data) + "\n", mode: 'w:UTF-8')
  FileUtils.mv(tmp, path)
end

def write_text(path, data)
  tmp = "#{path}.tmp"
  File.write(tmp, data, mode: 'w:UTF-8')
  FileUtils.mv(tmp, path)
end

def find_command(name)
  ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).each do |dir|
    path = File.join(dir, name)
    return path if executable_command?(path)
  end
  nil
end

def executable_command?(path)
  File.executable?(path) || (windows? && File.file?(path))
end

def stringify_keys(value)
  case value
  when Hash
    value.each_with_object({}) { |(k, v), memo| memo[k.to_s] = stringify_keys(v) }
  when Array
    value.map { |item| stringify_keys(item) }
  else
    value
  end
end

options = {
  output_directory: windows? ? 'C:/sbom' : '/var/sbom',
  base_name: 'ronin-sbom',
}

OptionParser.new do |parser|
  parser.on('--output-directory PATH') { |value| options[:output_directory] = value }
  parser.on('--base-name NAME') { |value| options[:base_name] = value }
end.parse!

inv = RoninSbom.new
init_puppet(inv)
collect_packages(inv)
collect_platform_packages(inv)
collect_taskcluster_binaries(inv)
collect_configuration(inv)

meta = metadata(inv)
FileUtils.mkdir_p(options[:output_directory])

base = File.join(options[:output_directory], options[:base_name])
write_json("#{base}.cdx.json", build_cyclonedx(meta, inv))
write_json("#{base}.inventory.json", build_inventory(meta, inv))
write_text("#{base}.md", build_markdown(meta, inv))

puts "Wrote #{base}.cdx.json"
puts "Wrote #{base}.inventory.json"
puts "Wrote #{base}.md"

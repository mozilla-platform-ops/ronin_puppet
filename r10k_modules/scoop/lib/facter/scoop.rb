Facter.add('scoop') do
  setcode do
    {
      buckets: [],
      packages: {},
    }
  end
end

Facter.add('scoop') do
  regkey_path = 'System\CurrentControlSet\Control\Session Manager\Environment'
  basedir = nil
  Win32::Registry::HKEY_LOCAL_MACHINE.open(regkey_path) do |regkey|
    basedir = regkey['SCOOP']
  end

  confine osfamily: :windows
  confine { basedir }

  setcode do
    scoop_exec = "#{basedir}\\shims\\scoop"
    ENV['SCOOP'] = basedir
    ENV['PATH'] += File::PATH_SEPARATOR + "#{basedir}\\shims"

    buckets = (Facter::Core::Execution.exec('powershell.exe -Command "scoop bucket list"') || '').strip.split(%r{\r?\n})

    package_list = (Facter::Core::Execution.exec('powershell.exe -Command "scoop export"') || '').strip.split(%r{\r?\n})

    packages = {}
    matcher = %r{^(?<name>[^ ]+) \(v:(?<version>[^ ]*)\)( ?(?<global>\*global\*)?)( \[(?<bucket>[^\]]+)\])?$}

    package_list.each do |line|
      result = line.match(matcher)
      next unless result

      packages[result[:name]] = {
        name: result[:name],
        version: result[:version],
        bucket: result[:bucket],
        global: result[:global] == '*global*',
      }
    end

    {
      exec: scoop_exec,
      basedir: basedir,
      buckets: buckets,
      packages: packages,
    }
  end
end

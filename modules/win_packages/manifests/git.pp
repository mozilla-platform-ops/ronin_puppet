# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::git (
  Pattern[/^\d+\.\d+\.\d+(\.\d+)?$/] $version,
) {
  require win_packages::staging

  $arch = $facts['custom_win_os_arch'] ? {
    'aarch64' => 'arm64',
    default   => '64-bit',
  }
  $release = $version =~ /^\d+\.\d+\.\d+\.\d+$/ ? {
    true    => regsubst($version, '^(\d+\.\d+\.\d+)\.(\d+)$', '\1.windows.\2'),
    default => "${version}.windows.1",
  }
  $installer = "Git-${version}-${arch}.exe"
  $path = "${win_packages::staging::path}\\${installer}"

  archive { 'git_installer':
    ensure  => present,
    source  => "https://github.com/git-for-windows/git/releases/download/v${release}/${installer}",
    path    => $path,
    extract => false,
    cleanup => false,
    require => Class['win_packages::staging'],
  }

  acl { $path:
    owner                      => 'S-1-5-18',
    inherit_parent_permissions => false,
    purge                      => true,
    permissions                => [
      { identity => 'S-1-5-18', rights => ['full'] },
      { identity => 'S-1-5-32-544', rights => ['full'] },
      { identity => 'S-1-5-32-545', rights => ['read', 'execute'] },
    ],
    require                    => Archive['git_installer'],
  }

  # Recheck at apply time so a missing or stale fact cannot downgrade Git.
  exec { 'git_minimum_version':
    command   => "\$process = Start-Process -FilePath '${path}' -ArgumentList '/VERYSILENT /NORESTART /SUPPRESSMSGBOXES /SP- /o:PathOption=Cmd' -Wait -PassThru; if (\$process.ExitCode -notin 0, 3010) { throw \"Git installer failed rc=\$(\$process.ExitCode)\" }",
    unless    => "\$git = Join-Path \$env:ProgramFiles 'Git\\bin\\git.exe'; if ((Test-Path \$git) -and ((Get-Command \$git).Version -ge [version]'${version}')) { exit 0 } else { exit 1 }",
    provider  => powershell,
    timeout   => 600,
    logoutput => true,
    require   => Acl[$path],
  }
}

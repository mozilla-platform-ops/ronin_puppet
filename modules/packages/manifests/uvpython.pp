# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Installs a uv-managed CPython (a python-build-standalone build) into
# $install_dir and points `python`, `python3` and `python3.<minor>` in $bin_dir
# at it.
#
# uv itself is NOT managed here: the caller installs uv and orders this class
# after it.
class packages::uvpython (
  Pattern[/^\d+\.\d+\.\d+$/] $version,
  String $uv_bin      = '/usr/local/bin/uv',
  String $install_dir = '/opt/tools/python',
  String $bin_dir     = '/usr/local/bin',
  String $platform    = 'macos-aarch64-none',
) {
  $short_version = split($version, '[.]')[0, 2].join('.')
  $interpreter = "${install_dir}/cpython-${version}-${platform}/bin/python${short_version}"

  # 0755 so the scriptworker users can run the interpreter root installs here.
  file { $install_dir:
    ensure => 'directory',
    owner  => 'root',
    group  => 'wheel',
    mode   => '0755',
  }

  # --no-bin because the links are managed below instead. uv's own `--default`
  # links resolve through a `cpython-<minor>-<platform>` symlink that it only
  # ever advances to newer patches: pointing at that would leave whatever patch
  # was installed last in charge rather than $version, and pinning back to an
  # older patch would never converge.
  exec { "install uv-managed python ${version}":
    command     => "${uv_bin} python install --no-bin ${version}",
    environment => ["UV_PYTHON_INSTALL_DIR=${install_dir}"],
    creates     => $interpreter,
    path        => ['/usr/bin', '/bin'],
    timeout     => 600,
    require     => File[$install_dir],
  }

  # force, so these can take over the links a python.org framework install
  # leaves in $bin_dir.
  ['python', 'python3', "python${short_version}"].each |String $link| {
    file { "${bin_dir}/${link}":
      ensure  => 'link',
      target  => $interpreter,
      force   => true,
      require => Exec["install uv-managed python ${version}"],
    }
  }
}

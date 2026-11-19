# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# @summary installs several (related) deb packages from s3
#
# `packages::linux_package_from_s3` installs one package at a time, so it  can't install complex dependent packages.
#
# This class aims to solve that.
#
# @example Basic usage
#   $pkgs_and_chksums_hash = {
#     'git_2.42.0-0ppa1~ubuntu18.04.1_amd64.deb' => '40e17918bff5544c252005433a565eecfe653228048108d7ff79de0548b9d552',
#     'git-man_2.42.0-0ppa1~ubuntu18.04.1_all.deb' => '56e6d53f07e3ed67b2e5c7602674f3951014d3591b6dcab5013ed69540784e3c' }
#
#   packages::linux_package_from_s3_multi { 'install git_242' :
#     packages_and_checksums => $pkgs_and_chksums_hash,
#     temp_dir               => '/var/cache/ronin-package-staging/git_242',
#     os_version_specific    => false,
#   }
#
# @param packages_and_checksums
#   Defines packages to install and their checksums.
# @param temp_dir
#   Where the deb packages will be stored on disk.
# @param bucket
#   S3 bucket where packages are.
# @param s3_domain
#   S3 domain.
# @param private
#   Is the package private or public?
# @param os_version_specific
#   Are the packagess OS version specific?
#
define packages::linux_package_from_s3_multi (
  # { 'file' => 'checksum', 'file2' => 'checksum2' }
  Hash[Pattern[/\A[A-Za-z0-9][A-Za-z0-9.+_~%-]*\.deb\z/], Pattern[/\A[0-9a-f]{64}\z/], 1] $packages_and_checksums,
  Pattern[/\A\/var\/cache\/ronin-package-staging\/[A-Za-z0-9_-]+\z/] $temp_dir,
  Optional[String] $bucket                     = undef,
  Optional[String] $s3_domain                  = undef,
  Boolean $private                             = false,
  Boolean $os_version_specific                 = true,
) {
  include packages::deb_staging
  include shared
  require packages::setup

  $_bucket = $bucket ? { true => $bucket, default => $packages::setup::default_bucket }
  $_s3_domain = $s3_domain ? { true => $s3_domain, default => $packages::setup::default_s3_domain }

  # Set path private or public
  $p = $private ? {
    true  => 'private',
    false => 'public'
  }

  # Set path os specific version or common
  $v = $os_version_specific ? {
    true  => $facts['os']['distro']['release']['major'],
    false => 'common'
  }

  # package with provider apt won't install from an url or a local file.
  # we're forced to fetch file, install with dpkg, then fix deps with apt.

  # ensure temp dir exists
  file { $temp_dir:
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    require => Class['packages::deb_staging'],
  }

  # define out here so we can require on resource later
  $packages_and_checksums.each | String $file, String $checksum | {
    $source = "https://${_s3_domain}/${_bucket}/linux/${p}/${v}/${file}"
    $destination = "${temp_dir}/${file}"

    file {
      default: * => $shared::file_defaults;

      $file:
        ensure         => 'file',
        path           => $destination,
        source         => $source,
        checksum       => 'sha256',
        checksum_value => $checksum,
        mode           => '0600',
        require        => File[$temp_dir],
    }
  }

  $destinations = $packages_and_checksums.keys.map |$file| { "${temp_dir}/${file}" }

  exec { "install package at ${temp_dir}":
    command => ['/usr/bin/apt', 'install', '-f', '-y'] + $destinations,
    unless  => [['/var/cache/ronin-package-staging/debs-installed'] + $destinations],
    require => $packages_and_checksums.keys.map |$file| { File[$file] },
  }
}

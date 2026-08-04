# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Restores the legacy Homebrew openssl@1.1 Cellar layout on Catalina build
# workers so newly-provisioned hosts match the ones provisioned before the
# current base image.
#
# Background: the macosx64-python-3.11 toolchain build (build-cpython.sh) has a
# post-build dylib fixup that hardcodes
#   /usr/local/Cellar/openssl@1.1/1.1.1h/lib/libcrypto.1.1.dylib
# in an `install_name_tool -change` followed by an `otool -L | grep` check.
# Workers provisioned long ago carry a real Homebrew Cellar 1.1.1h and match.
# Recently-provisioned workers ship openssl 1.1.1w laid directly under
# /usr/local/opt/openssl@1.1 (a real dir, no Cellar), so libssl references the
# opt path, the -change no-ops, the grep finds nothing and exits 1. That fails
# the toolchain build, which blocks every dependent task and PR.
#
# This class converges the newer layout back to the legacy Cellar layout so the
# hardcoded path resolves. It is a no-op on hosts that already match.
class packages::openssl_legacy_cellar (
  String $version  = '1.1.1h',
  String $checksum = '366f359fa6d5c397ce7c7860511080faf9c36537fc8747438d1b5d238cbf598c',
) {
  include packages::setup

  $tarball = "openssl-${version}-cellar.tar.gz"
  $tmp_tar = "/tmp/${tarball}"
  $url     = "https://${packages::setup::default_s3_domain}/${packages::setup::default_bucket}/macos/public/10.15/${tarball}"

  # Short-circuit once libssl already references the Cellar libcrypto path the
  # toolchain expects (true on the older fleet -> whole class no-ops there).
  $already_ok = "/bin/sh -c 'otool -L /usr/local/opt/openssl/lib/libssl.1.1.dylib 2>/dev/null | grep -qF \"Cellar/openssl@1.1/${version}/lib/libcrypto.1.1.dylib\"'"

  exec { 'fetch_openssl_legacy_cellar':
    command => "/usr/bin/curl -fL -o ${tmp_tar} ${url}",
    path    => ['/usr/bin', '/bin'],
    unless  => $already_ok,
    timeout => 120,
  }

  exec { 'verify_openssl_legacy_cellar':
    command => "/bin/sh -c 'echo \"${checksum}  ${tmp_tar}\" | /usr/bin/shasum -a 256 -c -'",
    path    => ['/usr/bin', '/bin'],
    unless  => $already_ok,
    require => Exec['fetch_openssl_legacy_cellar'],
  }

  # Extract to the Cellar, preserve any pre-existing opt tree as a .bak, then
  # point the opt symlinks at the restored Cellar version (matching the older
  # fleet). The .bak / symlink guards keep this safe to re-run.
  exec { 'install_openssl_legacy_cellar':
    command => "/bin/sh -c 'mkdir -p /usr/local/Cellar/openssl@1.1 && tar -xzf ${tmp_tar} -C /usr/local/Cellar/openssl@1.1 && { [ -L /usr/local/opt/openssl@1.1 ] || [ -e /usr/local/opt/openssl@1.1.bak ] || mv /usr/local/opt/openssl@1.1 /usr/local/opt/openssl@1.1.bak; } && ln -sfn ../Cellar/openssl@1.1/${version} /usr/local/opt/openssl@1.1 && ln -sfn openssl@1.1 /usr/local/opt/openssl'",
    path    => ['/usr/bin', '/bin'],
    unless  => $already_ok,
    require => Exec['verify_openssl_legacy_cellar'],
  }
}

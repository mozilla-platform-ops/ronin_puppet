# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::mercurial (
    Pattern[/^\d+\.\d+(\.\d+)?_?\d*$/] $version = '5.1',
) {

    # https://www.mercurial-scm.org/mac/binaries/Mercurial-5.1-macosx10.14.pkg
    # bd23d361130fa4a70a7783ceb089882935444c6cc0679b50d1aa6e1bb4c4fe98

    packages::macos_package_from_s3 { "Mercurial-${version}-macosx10.14.pkg":
        private             => false,
        os_version_specific => true,
        type                => 'pkg',
    }

    # libdir = '../../Library/Python/2.7/site-packages/'   # 5.1 pkg hg (LIBDIR)
    # libdir = '../../../Library/Python/2.7/site-packages' # 5.5+ pkg hg
    if ! '11' == $facts['os']['macosx']['version']['major']
      and $version == '5.1' {
        file { '/usr/Library':
            ensure  => 'link',
            target  => '/Library',
            require => Class['packages::python2'];
        }
    }
}

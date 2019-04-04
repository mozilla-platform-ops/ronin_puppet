# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define mercurial::repo (
    String $hg_repo,
    String $dst_dir,
    String $user,
    String $branch = '',
    String $rev = '',
) {

    include packages::py27_mercurial

    if ($branch == '' and $rev == '') {
        fail('Must specify one of rev or branch')
    }

    $branch_arg = $branch ? {
        ''      => '',
        default => "-b ${branch}"
    }

    $rev_arg = $rev ? {
        ''      => '',
        default => "-r ${rev}"
    }

    exec { "clone-${dst_dir}":
        require => Class['packages::py27_mercurial'],
        command => "${::packages::py27_mercurial::mercurial} clone ${branch_arg} ${rev_arg} ${hg_repo} ${dst_dir}",
        creates => $dst_dir,
        user    => $user,
    }
}

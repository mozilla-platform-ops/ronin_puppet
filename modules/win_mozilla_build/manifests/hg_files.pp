# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build::hg_files {

    $mozbld = $win_mozilla_build::install_path

    file { "${mozbld}\\robustcheckout.py":
        content => file('win_mozilla_build/robustcheckout.py'),
    }
    file { "${win_mozilla_build::install_path}\\msys\\cacert.pem":
        content => file('win_mozilla_build/cacert.pem'),
    }
    file { "${win_mozilla_build::program_files}\\mercurial\\mercurial.ini":
        content => file('win_mozilla_build/mercurial.ini'),
    }
    file { "${win_mozilla_build::system_drive}\\hg-shared":
        ensure => directory,
    }
    acl { "${win_mozilla_build::system_drive}\\hg-shared":
        target      => "${win_mozilla_build::system_drive}\\hg-shared",
        permissions => {
            identity                   => 'everyone',
            rights                     => ['full'],
            type                       => 'allow',
            child_types                => 'all',
            affects                    => 'all',
            inherit_parent_permissions => true,
        }
    }
}

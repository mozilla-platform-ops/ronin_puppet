# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class linux_packages::google_chrome {
    include apt

    Exec['apt_update'] -> Package['google-chrome-stable']

    # setup chrome source
    apt::source { 'google_repo':
        location => '[arch=amd64] https://dl.google.com/linux/chrome/deb/',
        release  => 'stable',
        key      => {
            id     => '4CCA1EAF950CEE4AB83976DCA040830F7FAC5991',
            source => 'https://dl.google.com/linux/linux_signing_key.pub',
        },
        repos    => 'main',
        include  => {
            'src' => false
        },
        notify   => Exec['apt_update'],
    }

    # configure auto-update
    schedule { 'update-chrome-schedule':
        period => weekly,
        repeat => 1,
    }
    exec { 'update-chrome-action':
        schedule => 'update-chrome-schedule',
        command  => '/usr/bin/apt-get update -o \
            Dir::Etc::sourcelist="sources.list.d/google-chrome.list" \
            -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"',
    }

    # install chrome
    package {
        'google-chrome-stable':
            ensure => latest;
    }
}

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class pf {
    $osx_ver = 'mojave'
    # The default /etc/pf.conf differs between major osx version
    #case $facts['os']['macosx']['version']['major'] {
    #    '10.14': {
    #        $osx_ver = 'mojave'
    #    }
    #    default: {
    #        fail("OSX ${::macosx_productversion_major} is not supported")
    #    }
    #}

    # Default ethernet interface
    $iface    = 'en0'
    $pf_dir   = '/etc/pf.mozilla.anchors'
    $pfctl    = '/sbin/pfctl'
    $pf_entry = '/etc/pf.conf'

    file {
        $pf_dir:
            ensure => 'directory',
            owner  => 'root',
            group  => 'wheel',
            mode   => '0700';

        "${pf_dir}/main.conf":
            ensure  => file,
            owner   => 'root',
            group   => 'wheel',
            mode    => '0600',
            content => template('pf/main.conf.erb'),
            require => File[$pf_dir],
            notify  => Exec['update_pf'];
    }

    concat {
        "${pf_dir}/tables.conf":
            owner   => 'root',
            group   => 'wheel',
            mode    => '0600',
            require => File[$pf_dir],
            notify  => Exec['update_pf'];

        "${pf_dir}/rules.conf":
            owner   => 'root',
            group   => 'wheel',
            mode    => '0600',
            require => File[$pf_dir],
            notify  => Exec['update_pf'];
    }

    file {
        $pf_entry:
            ensure => present,
            owner  => 'root',
            group  => 'wheel',
            notify => Exec['update_pf'],
            source => "puppet:///modules/pf/pf.conf.${osx_ver}";

        '/Library/LaunchDaemons/org.mozilla.pf.plist':
            ensure => present,
            source => 'puppet:///modules/pf/org.mozilla.pf.plist';

        '/Library/LaunchDaemons/org.mozilla.pflog.plist':
            ensure => present,
            source => 'puppet:///modules/pf/org.mozilla.pflog.plist',
            notify => Service['org.mozilla.pflog'];

        '/usr/local/bin/pflog.sh':
            ensure => present,
            mode   => '0755',
            source => 'puppet:///modules/pf/pflog.sh',
            notify => Service['org.mozilla.pflog'];
    }

    service { 'org.mozilla.pflog':
        ensure  => running,
        enable  => true,
        require => File['/usr/local/bin/pflog.sh', '/Library/LaunchDaemons/org.mozilla.pflog.plist'],
    }

    exec {
        'update_pf':
            command     => "${pfctl} -nf ${pf_entry} && ${pfctl} -f ${pf_entry}",
            refreshonly => true;

        'enable_pf':
            command => "${pfctl} -e",
            onlyif  => '/bin/test `pfctl -sa| grep "Status" | awk \'/Status:/ {print $2}\'` != "Enabled"';
    }
}

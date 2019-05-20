# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
class signing_worker::base {
    # Dependencies

    contain packages::p7zip
    contain packages::python3
    file { '/tools/python3':
        ensure  => 'link',
        target  => '/usr/local/bin/python3',
        require => Class['packages::python3'],
    }

    file { $signing_worker::tmp_requirements:
        source => 'puppet:///modules/signing_worker/requirements.txt',
    }

    contain packages::virtualenv
    python::virtualenv { 'signingworker' :
        ensure          => present,
        version         => '3',
        requirements    => $signing_worker::tmp_requirements,
        venv_dir        => $signing_worker::virtualenv_dir,
        ensure_venv_dir => true,
        owner           => $signing_worker::user,
        group           => $signing_worker::group,
        timeout         => 0,
    }
    # scriptworker config
    file { $signing_worker::config_file:
        content => template('signing_worker/scriptworker_config.erb'),
    }

    # Start service
    supervisord::supervise {
      'signingworker':
          command      => "${signing_worker::virtualenv_dir}/bin/iscript ${signing_worker::config_file}",
          user         => $signing_worker::user,
          extra_config => template('signing_worker/supervisor_config.erb');
  }

}

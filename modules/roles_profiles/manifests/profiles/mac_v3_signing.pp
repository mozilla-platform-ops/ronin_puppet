# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class roles_profiles::profiles::mac_v3_signing {
  case $facts['os']['name'] {
    'Darwin': {
      $worker_type  = 'mac-v3-signing'
      $worker_group = regsubst($facts['networking']['fqdn'], '.*\.releng\.(.+)\.mozilla\..*', '\1')

      class { 'roles_profiles::profiles::logging':
        worker_type => $worker_type,
      }

      include dirs::tools

      class { 'scriptworker_prereqs': }

      $widevine_user = lookup('widevine_config.user')
      $widevine_key = lookup('widevine_config.key')

      $role = $facts['networking']['hostname']? {
        /^dep-mac-v3-signing\d+/ => 'dep',
        /^tb-mac-v3-signing\d+/ => 'tb-prod',
        /^vpn-mac-v3-signing\d+/ => 'vpn',
        default => 'ff-prod',
      }

      $worker_common = lookup("scriptworker_config.${role}", Hash, undef, {})
      $worker_secrets = lookup("scriptworker_secrets.${role}", Hash, undef, {})
      $worker_config = deep_merge($worker_common, $worker_secrets)

      $role_common = lookup("signingworker_roles.${role}", Hash, undef, {})
      $role_secrets = lookup("signing_secrets.${role}", Hash, undef, {})
      $role_config = deep_merge($role_common, $role_secrets)

      $scriptworker_users = lookup("scriptworker_users.${role}")

      # Determine macOS version for correct scriptworker path
      $mac_version = $facts['os']['release']['major']

      # Set scriptworker_base depending on macOS version
      $scriptworker_base = $mac_version ? {
        '18'    => '/builds/scriptworker',  # macOS 10.14
        '19'    => '/builds/scriptworker',  # macOS 10.15 (assuming same as 10.14)
        '21'    => '/usr/local/builds/scriptworker',  # macOS 14+
        '23'    => '/usr/local/builds/scriptworker',  # macOS 14+
        default => fail("Unsupported macOS version: ${mac_version}"),
      }

      $exe_path = $mac_version ? {
        '18'    => '/builds/scriptworker/bin/scriptworker',  # macOS 10.14
        '19'    => '/builds/scriptworker/bin/scriptworker',  # macOS 10.15
        '21'    => '/usr/local/builds/scriptworker/bin/scriptworker',  # macOS 14+
        '23'    => '/usr/local/builds/scriptworker/bin/scriptworker',  # macOS 14+
        default => fail("Unsupported macOS version: ${mac_version}"),
      }

      $scriptworker_users.each |String $user, Hash $user_data| {
        signing_worker { "signing_worker_${user}":
          role                => $role,
          user                => $user,
          password            => lookup("${user}_user.password"),
          salt                => lookup("${user}_user.salt"),
          iterations          => lookup("${user}_user.iterations"),
          scriptworker_base   => $scriptworker_base,  # <-- Hardcoded based on macOS version
          dmg_prefix          => $user_data['dmg_prefix'],
          worker_type_prefix  => $user_data['worker_type_prefix'],
          worker_id_suffix    => $user_data['worker_id_suffix'],
          cot_product         => $user_data['cot_product'],
          supported_behaviors => $user_data['supported_behaviors'],
          widevine_user       => $widevine_user,
          widevine_key        => $widevine_key,
          widevine_filename   => $user_data['widevine_filename'],
          keychain_filename   => $user_data['keychain_filename'],
          worker_config       => $worker_config,
          role_config         => $role_config,
          ed_key_filename     => $user_data['ed_key_filename'],
        }
      }

      class { 'telegraf':
        global_tags  => {
          workerType    => $worker_type,
          workerGroup   => $worker_group,
          provisionerId => 'scriptworker-prov-v1',
          role          => $role,
          workerId      => $facts['networking']['hostname'],
        },
        agent_params => {
          interval          => '300s',
          round_interval    => true,
          collection_jitter => '0s',
          precision         => 's',
        },
        inputs       => {
          system      => {},
          temp        => {},
          cpu         => {
            interval         => '60s',
            percpu           => true,
            totalcpu         => true,
            collect_cpu_time => false,
            report_active    => false,
          },
          mem         => {},
          swap        => {},
          disk        => {
            mount_points => ['/'],
          },
          diskio      => {},
          procstat    => {
            interval => '60s',
            exe      => $exe_path,
          },
          procstat2   => {
            plugin_type => 'procstat',
            interval    => '60s',
            pattern     => 'tools/release/signing/signing-server.py',
          },
          puppetagent => {
            location => '/opt/puppetlabs/puppet/cache/state/last_run_summary.yaml',
          },
        },
      }

      class { 'puppet::periodic':
        telegraf_user     => lookup('telegraf.user'),
        telegraf_password => lookup('telegraf.password'),
        puppet_repo       => 'https://github.com/mozilla-platform-ops/ronin_puppet.git',
        puppet_branch     => 'macos-signer-latest',
        meta_data         => {
          workerType    => $worker_type,
          workerGroup   => $worker_group,
          provisionerId => 'scriptworker-prov-v1',
          workerId      => $facts['networking']['hostname'],
        },
      }
    }
    default: {
      fail("${facts['os']['name']} not supported")
    }
  }
}

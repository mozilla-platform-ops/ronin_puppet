# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::vac (
    String $flags,
    String $installer,
    Integer $install_timeout,
    String $package,
    String $srcloc,
    String $trusted_publisher_cat,
    String $vac_dir,
    String $work_dir
) {
    include win_packages::staging

    $exe_name = "${work_dir}\\${installer}"
    $pkgdir   = $win_packages::staging::path
    $src_file = "\"${pkgdir}\\${package}\""


    file { $vac_dir:
        ensure => directory,
    }
    acl { $vac_dir:
        owner                      => 'S-1-5-18',
        inherit_parent_permissions => false,
        purge                      => true,
        permissions                => [
            { identity => 'S-1-5-18', rights => ['full'] },
            { identity => 'S-1-5-32-544', rights => ['full'] },
            { identity => 'S-1-5-32-545', rights => ['read', 'execute'] },
        ],
        require                    => File[$vac_dir],
    }
    file { "${pkgdir}\\${package}":
        source  => "${srcloc}/${package}",
        require => Class['win_packages::staging'],
    }
    acl { "${pkgdir}\\${package}":
        owner                      => 'S-1-5-18',
        inherit_parent_permissions => false,
        purge                      => true,
        permissions                => [
            { identity => 'S-1-5-18', rights => ['full'] },
            { identity => 'S-1-5-32-544', rights => ['full'] },
            { identity => 'S-1-5-32-545', rights => ['read', 'execute'] },
        ],
        require                    => File["${pkgdir}\\${package}"],
    }
    exec {  'vac_unzip':
        command  => "Expand-Archive -Path ${src_file} -DestinationPath ${vac_dir}\\",
        creates  => $exe_name,
        provider => powershell,
        require  => [Acl["${pkgdir}\\${package}"], Acl[$vac_dir]],
    }
    acl { [$work_dir, $exe_name]:
        owner                      => 'S-1-5-18',
        inherit_parent_permissions => false,
        purge                      => true,
        permissions                => [
            { identity => 'S-1-5-18', rights => ['full'] },
            { identity => 'S-1-5-32-544', rights => ['full'] },
            { identity => 'S-1-5-32-545', rights => ['read', 'execute'] },
        ],
        require                    => Exec['vac_unzip'],
    }

    if $trusted_publisher_cat != '' {
        exec { 'vac_trust_publisher':
            command     => "\$catPath = '${work_dir}\\${trusted_publisher_cat}'; if (-not (Test-Path -LiteralPath \$catPath)) { throw ('Missing VAC catalog: ' + \$catPath) }; \$signature = Get-AuthenticodeSignature -LiteralPath \$catPath; if (\$signature.Status -ne 'Valid') { throw ('VAC catalog signature is ' + \$signature.Status + ': ' + \$catPath) }; \$certPath = Join-Path '${work_dir}' 'vac-publisher.cer'; Export-Certificate -Cert \$signature.SignerCertificate -FilePath \$certPath -Force | Out-Null; Import-Certificate -FilePath \$certPath -CertStoreLocation 'Cert:\\LocalMachine\\TrustedPublisher' -ErrorAction Stop | Out-Null",
            provider    => powershell,
            subscribe   => Exec['vac_unzip'],
            refreshonly => true,
            require     => Acl[$work_dir],
        }

        Exec['vac_trust_publisher'] -> Exec['vac_install']
    }

    exec { 'vac_install':
        command     => "\$process = Start-Process -FilePath '${exe_name}' -ArgumentList '${flags}' -Wait -PassThru; exit \$process.ExitCode",
        provider    => powershell,
        returns     => [0, 3010, 1641],
        subscribe   => Exec['vac_unzip'],
        timeout     => $install_timeout,
        refreshonly => true,
        require     => Acl[$exe_name],
    }
}

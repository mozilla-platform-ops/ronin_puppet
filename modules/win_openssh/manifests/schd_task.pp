class win_openssh::schd_task {

    $enable_ssh = "${facts['custom_win_roninprogramdata']}\\enable_openssh.ps1"

    file { $enable_ssh:
        content => file('win_openssh/enable_openssh.ps1'),
    }
    # Resource from puppetlabs-scheduled_task
    scheduled_task { 'enable_openssh':
        ensure    => 'present',
        command   => "${facts['custom_win_system32']}\\WindowsPowerShell\\v1.0\\powershell.exe",
        arguments => "-executionpolicy bypass -File ${enable_ssh}",
        enabled   => true,
        trigger   => [{
            'schedule'         => 'boot',
            'minutes_interval' => '0',
            'minutes_duration' => '0'
        }],
        user      => 'system',
    }
}

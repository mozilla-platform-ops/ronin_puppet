# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class macos_utils::autologin_user (
    String $user,
    String $kcpassword,
    Optional[String] $remove = false,
) {

    include stdlib

    if $::operatingsystem == 'Darwin' {
        if $remove == true {
            $defaults_cmd = '/usr/bin/defaults'
            $domain = '/Library/Preferences/com.apple.loginwindow'
            exec { "osx_defaults write ${domain} autoLoginUser=>${user}" :
                command => "${defaults_cmd} delete ${domain} autoLoginUser",
                onlyif  => "/bin/test x$(${defaults_cmd} read ${domain} autoLoginUser) = x'${user}'",
            }
        } else {
            macos_utils::defaults { 'autologin_user':
                domain => '/Library/Preferences/com.apple.loginwindow',
                key    => 'autoLoginUser',
                value  => $user,
            }
            macos_utils::defaults { 'autologin_user_screen_locked':
                domain   => '/Library/Preferences/com.apple.loginwindow',
                key      => 'autoLoginUserScreenLocked',
                value    => '0',
                val_type => 'int',
            }
            file { '/etc/kcpassword':
                content   => base64('decode', $kcpassword),
                owner     => root,
                group     => wheel,
                mode      => '0600',
                show_diff => false;
            }
        }
    } else {
        fail("${module_name} does not support ${::operatingsystem}")
    }
}

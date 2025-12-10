# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# @summary Manages the message of the day (MOTD) file
#
# This class configures the MOTD file for Mozilla infrastructure servers,
# displaying ASCII art and an unauthorized access warning. The implementation
# varies by operating system:
#
# - Ubuntu: Includes the Mozilla ASCII art, OS information from the system's
#   00-header script, and an unauthorized access warning
# - Darwin (macOS): Displays the Mozilla ASCII art with an unauthorized access warning
#
# The MOTD file is managed using concat to allow other classes to add additional
# fragments as needed.
#
# @example
#   include motd::base
#
class motd::base {
  include motd::settings

  $group = $facts['os']['name'] ? {
    'Darwin' => 'wheel',
    default  => 'root'
  }
  concat { $motd::settings::motd_file:
    owner => 'root',
    group => $group,
    mode  => '0644';
  }

  case $facts['os']['name'] {
    'Ubuntu': {
      # NOTE: The MOTD greeting on Ubuntu 18+ is dynamically generated at login
      # - /etc/motd is just appended to the end of the dynamic MOTD
      # - see /etc/update-motd.d/ for the scripts that generate the dynamic part

      # same as darwin, but include os info by calling /etc/update-motd.d/00-header
      concat::fragment { 'base-motd':
        target => $motd::settings::motd_file,
      content  => "
                             _ _ _
                           (_) | |           .--.
         _ __ ___   ___ _____| | | __ _     |o_o |
        | '_ ` _ \\ / _ \\_  / | | |/ _` |    |:_/ |
        | | | | | | (_) / /| | | | (_| |   //   \\ \\\\
        |_| |_| |_|\\___/___|_|_|_|\\__,_|  (|     | )
                                          /'\\_   _/`\\
                                         \\___)=(___/

           *** Unauthorized access prohibited ***

", }
      # show DISTRIB_DESCRIPTION= info from /etc/lsb-release
      concat::fragment { 'os-info-motd':
        target => $motd::settings::motd_file,
      content  => inline_epp('@EOT
<% | String $lsb_release_file = "/etc/lsb-release" | -%>
<% if file($lsb_release_file) =~ /DISTRIB_DESCRIPTION="(.*)"/m -%>
OS: <%= $1 %>
<% else -%>
OS: Unknown
<% endif -%>
EOT
        '),
      }
    }  # end ubuntu case
    'Darwin': {
      # need at least one fragment, or concat will fail:
      concat::fragment { 'base-motd':
        target  => $motd::settings::motd_file,
        content => "
    ┌───┬──┐                         _ _ _
    │ ╷╭╯╷ │                       (_) | |           .--.
    │  └╮  │     _ __ ___   ___ _____| | | __ _     |o_o |
    │ ╰─┼╯ │    | '_ ` _ \\ / _ \\_  / | | |/ _` |    |:_/ |
    └───┴──┘    | | | | | | (_) / /| | | | (_| |   //   \\ \\\\
                |_| |_| |_|\\___/___|_|_|_|\\__,_|  (|     | )
                                                  /'\\_   _/`\\
                                                 \\___)=(___/
Unauthorized access prohibited
        ",
      }
      # TODO: show specific OS platform (Linux, Mac) and OS version (1804, 2404)
      # TODO: show override info? could be incorrect if we haven't run puppet recently...
    }

    default: {
      fail("motd module does not support OS ${facts['os']['name']}")
    }
  }
}

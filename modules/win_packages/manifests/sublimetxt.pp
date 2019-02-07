# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_packages::sublimetxt {
    defined_classes::pkg::win_exe_pkg  { "sublime_text":
        pkg                    => "SublimeTextBuild3176x64Setup.exe",
        install_options_string => "/VERYSILENT /NORESTART /TASKS=\"contextentry\"",
        creates                => "${facts['programfiles']}\\Sublime Text 3\\subl.exe",
    }
}

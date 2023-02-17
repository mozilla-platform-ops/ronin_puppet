# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_mozilla_build_tester::hg_files {
  $mozbld      = "C:\\mozilla-build"
  # Reference  https://bugzilla.mozilla.org/show_bug.cgi?id=1305485#c5
  file { "${mozbld}\\robustcheckout.py":
    content => file('win_mozilla_build/robustcheckout.py'),
  }
  file { "${$facts['custom_win_programfiles']}\\mercurial\\mercurial.ini":
    content => file('win_mozilla_build/mercurial.ini'),
  }
}

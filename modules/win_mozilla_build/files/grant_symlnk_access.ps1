# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

C:\Program Files\Mercurial\hg.exe clone --insecure https://bitbucket.org/splatteredbits/carbon C:\Windows\Temp\carbon

C:\Program Files\Mercurial\hg.exe update 2.4.0 -R C:\Windows\Temp\carbon

xcopy C:\Windows\Temp\carbon\carbon C:\Windows\Temp\carbon C:\Windows\System32\WindowsPowerShell\v1.0\Modules\Carbon /e /i /y

Import-Module carbon
Grant-Privilege' -Identity Everyone -Privilege SeCreateSymbolicLinkPrivilege

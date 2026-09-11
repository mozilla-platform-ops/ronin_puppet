# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

Set-Location $env:windir\System32\WindowsPowerShell\v1.0\Modules\Carbon

.\Import-Carbon.ps1
Grant-Privilege -Identity Everyone -Privilege SeCreateSymbolicLinkPrivilege
Grant-Privilege -Identity System -Privilege SeCreateSymbolicLinkPrivilege

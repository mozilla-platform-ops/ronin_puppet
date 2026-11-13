# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Bug 2092632: the November 2026 cumulative update (KB5132061, build 26200.9974)
# makes NTLM clients offer message signing on all non-anonymous connections
# (KB5135557, phase 1). The fake NTLM servers in the Gecko xpcshell tests
# (test_ntlm_native_server_validation.js, test_ntlm_web_auth.js) do not offer
# signing, so SSPI does not send a Type 3 message and the tests fail.
#
# ClientAllowUnsignedNtlm = 1 restores the previous client behavior. This is a
# temporary compatibility setting. Remove it when the tests offer signing.
class win_os_settings::ntlm_client_signing {
  registry::value { 'ClientAllowUnsignedNtlm' :
    key  => 'HKLM\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0',
    type => dword,
    data => '1',
  }
}

# Bug list
# https://bugzilla.mozilla.org/show_bug.cgi?id=2092632
# https://support.microsoft.com/help/5135557

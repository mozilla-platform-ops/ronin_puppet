# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define macos_utils::defaults (
    Optional[String] $domain = undef,
    Optional[String] $key = undef,
    Optional[String] $value = undef,
    String $user = 'root',
    Enum['string', 'int', 'float', 'bool', 'date', 'array'] $type = 'string',
) {

    $defaults_cmd = '/usr/bin/defaults'
    if ($domain != undef) and ($key != undef) and ($value != undef) {
        exec { "osx_defaults write ${domain} ${key}=>${value}" :
            command => "${defaults_cmd} write ${domain} ${key} -${type} ${value}",
            unless  => "/bin/test x`${defaults_cmd} read ${domain} ${key}` = x'${value}'",
            user    => $user,
        }
    }
    else {
        fail('Cannot ensure present without domain, key, and value attributes')
    }
}

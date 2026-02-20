# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

define macos_utils::defaults (
  Optional[String] $domain = undef,
  Optional[String] $key = undef,
  Optional[String] $value = undef,
  String $user = 'root',
  Enum['string', 'int', 'float', 'bool', 'date', 'array'] $val_type = 'string',
) {
  $defaults_cmd = '/usr/bin/defaults'
  # macOS 10.15+ requires 'true'/'false' for -bool, not '0'/'1'.
  # 'defaults read' returns '0'/'1', so $value is used in the unless check
  # while $write_value is used in the actual write command.
  if $val_type == 'bool' {
    $write_value = $value ? {
      '0'     => 'false',
      '1'     => 'true',
      default => $value,
    }
  } else {
    $write_value = $value
  }
  if ($domain != undef) and ($key != undef) and ($value != undef) {
    exec { "osx_defaults write ${domain} ${key}=>${value}" :
      command => "${defaults_cmd} write ${domain} ${key} -${val_type} ${write_value}",
      unless  => "/bin/test x`${defaults_cmd} read ${domain} ${key}` = x'${value}'",
      user    => $user,
    }
  }
  else {
    fail('Cannot ensure present without domain, key, and value attributes')
  }
}

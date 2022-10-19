# @summary Configure a Scoop bucket
#
# @example Add a bucket
#   scoop::bucket { 'extras':
#     ensure => 'present',
#   }
#
# @example Remove a bucket
#   scoop::bucket { 'extras':
#     ensure => 'absent',
#   }
#
# @example Add a bucket by url
#   scoop::bucket { 'wangzq':
#     ensure => 'present',
#     url    => 'https://github.com/wangzq/scoop-bucket',
#   }
#
# @param name
#   The name of the bucket to create.
#
# @param ensure
#   Specifies whether to create the bucket. Valid values are 'present', 'absent'. Defaults to 'present'.
#
# @param url
#   Specifies the URL where the bucket's content is found. Defaults to undef, which means it should be a known bucket.
#
define scoop::bucket (
  Enum['present', 'absent'] $ensure = 'present',
  Optional[String] $url = undef,
) {
  include ::scoop::install

  $is_configured = member($facts['scoop']['buckets'], $name)

  case $ensure {
    'absent': {
      if $is_configured {
        exec { "remove bucket ${name}":
          command     => "${scoop::set_path}; ${scoop::scoop_exec} bucket rm '${name}'",
          environment => [
            "SCOOP=${scoop::basedir}",
          ],
          provider    => 'powershell',
        }
      }
    }
    default: {
      # Empty url is ok; it then adds it from the "known" list
      # https://github.com/lukesampson/scoop/blob/master/buckets.json

      unless $is_configured {
        exec { "add bucket ${name}":
          command     => "${scoop::set_path}; ${scoop::scoop_exec} bucket add '${name}' '${url}'",
          environment => [
            "SCOOP=${scoop::basedir}",
          ],
          provider    => 'powershell',
          logoutput   => true,
        }
      }
    }
  }
}

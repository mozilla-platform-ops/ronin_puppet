# @summary Configures the system timezone.
#
# Configures the system timezone.
#
# @param timezone
#   Name of the timezone to configure.
#
# @param rtc_is_utc
#   Whether the RTC is on UTC time or local time.
#
# @param package
#   Package to install.
#
# @param timedatectl_cmd
#   Command used to set the timezone.
#
# @param timedatectl_chk
#   Command used to test the current timezone setting.
#
# @param setlocalrtc_cmd
#   Command used to set if RTC is on UTC time or local time.
#
# @param setlocalrtc_chk
#   Command used to test the current setting of RTC.
#
# @example Configures the system for timezone UTC with RTC on UTC time.
#   class { 'timezone':
#     timezone   => 'UTC',
#     rtc_is_utc => true,
#   }
#
# @example Previous example but configured with data provided by hiera.
#   timezone::timezone:   'UTC'
#   timezone::rtc_is_utc: true
#
#   include timezone
#
# @example Configures the system for timezone Europe/Stockholm with RTC on UTC time.
#   class { 'timezone':
#     timezone   => 'Europe/Stockholm',
#     rtc_is_utc => true,
#   }
#
# @example Previous example but configured with data provided by hiera.
#   timezone::timezone:   'Europe/Stockholm'
#   timezone::rtc_is_utc: true
#
#   include timezone
#
class timezone (
  Timezone::Timezone   $timezone,
  Boolean              $rtc_is_utc,
  String               $package,
  Stdlib::Absolutepath $timedatectl_cmd,
  Stdlib::Absolutepath $timedatectl_chk,
  Stdlib::Absolutepath $setlocalrtc_cmd,
  Stdlib::Absolutepath $setlocalrtc_chk,
) {
  package { $package:
    ensure => present,
  }

  exec { 'set-timezone':
    command => "${timedatectl_cmd} ${timezone}",
    unless  => "${timedatectl_chk} '${timezone}'",
    require => Package[$package],
  }

  $rtc_set = $rtc_is_utc ? { true => '0', false => '1' }
  $rtc_chk = $rtc_is_utc ? { true => 'no', false => 'yes' }

  exec { 'set-local-rtc':
    command => "${setlocalrtc_cmd} ${$rtc_set}",
    unless  => "${setlocalrtc_chk} ${rtc_chk}",
    require => Package[$package],
  }
}

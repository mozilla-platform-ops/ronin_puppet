# @summary update Safari to the latest version
#   - this only runs once and depends on SEMAPHOREPATH/updated-safari to not exist already
#

class macos_updatesafari(
  String $user_running_safari = 'cltbld'
) {
  $update_script = "/usr/local/bin/macos1015-safariupdate.sh"

  file { $update_script:
    content => file('macos_safari_update/macos1015-safariupdate.sh'),
    mode    => '0755',
  }

  # needs to run as cltbld via launchctl or won't work
  exec { 'execute update safari script':
    # TODO: don't hardcode user id of cltbld
    #   - make a driver script that gets id of cltbld on each system?
    command => "/bin/launchctl asuser 36 sudo -u ${user_running_safari} ${update_script}",
    require => File[$update_script],
    # semaphore created in script
    unless  => "/bin/test -f /Users/${user_running_safari}/Library/Preferences/semaphore/safari-update-has-run",
    # logoutput => true,
  }
}

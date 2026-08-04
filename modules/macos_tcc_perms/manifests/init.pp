# @summary adds tcc permissions for bash/terminal screen recording
#
#
class macos_tcc_perms (
  Boolean $enabled = true,
) {
  if $enabled {
    case $facts['os']['release']['major'] {
      '19','20','21','22','23', '24': {
        $tcc_script = '/usr/local/bin/tcc_perms.sh'

        file { $tcc_script:
          content => file('macos_tcc_perms/tcc_perms.sh'),
          mode    => '0755',
        }

        # in CI, this tcc.db file doesn't exist yet, so skip running the script
        #
        # `--check` is the script's own idempotence check: applied at least once
        # AND applied against the worker binaries currently on disk. A bare
        # semaphore test was not enough -- some of the grants the script writes
        # are anchored to the binaries' cdhashes, so a binary swap (version bump,
        # or a pool moving onto Developer-ID-signed builds) leaves those grants
        # pointing at a cdhash that no longer exists. TCC keeps the row and
        # silently ignores it, so the symptom is denied screen capture with a
        # grant that still looks present.
        if $facts['running_in_test_kitchen'] != 'true' {
          exec { 'execute tcc perms script':
            command => $tcc_script,
            require => File[$tcc_script],
            user    => 'root',
            unless  => "${tcc_script} --check",
          }
        }
      }
      default: {
        fail("${facts['os']['release']} not supported")
      }
    }
  }
}

# @summary Installs or uninstalls Scoop
#
# @api private
#
class scoop::install {
  $tester = "try { if (Test-Path -path ${scoop::scoop_exec}) { exit 1 } } catch { exit 0 }"

  case $scoop::ensure {
    'absent': {
      Scoop::Package <| |> -> Scoop::Bucket <| |>
      -> exec { 'uninstall scoop':
        command     => "${scoop::set_path}; ${scoop::scoop_exec} uninstall scoop --global",
        environment => [
          "SCOOP=${scoop::basedir}",
        ],
        unless      => $tester,
        provider    => 'powershell',
        logoutput   => true,
      }
    }
    default: {
      exec { 'install scoop':
        command     => file('scoop/install.ps1'),
        environment => [
          "SCOOP=${scoop::basedir}",
        ],
        onlyif      => $tester,
        provider    => 'powershell',
        logoutput   => true,
      }
      -> Scoop::Bucket <| |> -> Scoop::Package <| |>
    }
  }
}

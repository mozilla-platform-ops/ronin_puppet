# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_download (
  String $url,
  String $destination_directory,
  String $destination_file,
  String $pkgname
) {
  if $destination_file {
    $filename = $destination_file
  } else {
    $filename = regsubst($url, '^http.*\/([^\/]+)$', '\1')
  }

  $file_path = "${destination_directory}\\download-${pkgname}.ps1"

  file { "download-${pkgname}.ps1":
    ensure  => file,
    path    => $file_path,
    content => template('download_file/download.ps1.erb'),
  }

  exec { "download-${filename}":
    command   => $file_path,
    provider  => powershell,
    onlyif    => "if(Test-Path -Path '${destination_directory}\\${filename}') { exit 1 } else { exit 0 }",
    logoutput => true,
    require   => File["download-${filename}.ps1"],
  }
}

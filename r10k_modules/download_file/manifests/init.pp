# Author::    Paul Stack  (mailto:pstack@opentable.com)
# Copyright:: Copyright (c) 2013 OpenTable Inc
# License::   MIT

# == Define Resource Type: download_file
#
# The download_file module allows you to download files on Windows
#
# === Requirements/Dependencies
#
# Currently requires the modules puppetlabs/stdlib and puppetlabs/powershell on
# the Puppet Forge in order to validate much of the the provided configuration.
#
# === Parameters
#
# [*url*]
# The http(s) destination of the file that you are looking to download
#
# [*destination_directory*]
# The full path to the directory on the system where the file will be downloaded to
#
# [*destination_file*]
# The optional name of the file to download onto the system.
#
# [*proxy_address*]
# The optional http proxy address to use when downloading the file
#
# [*proxy_user*]
# When using a proxy, the optional authentication user name.
#
# [*proxy_password*]
# When using a proxy, the optional authentication password.
#
# [*is_password_secure*]
# Boolean value. If true, proxy_password is assumed to be a securestring. Defaults to true.
#
# [*timeout*]
# The optional timeout(in seconds) in case you expect to download big and slow file
#
# [*cookies*]
# An optional array of cookies to add to the HTTP request for the download.
#
# [*user_agent*]
# The optional user agent string to be sent when downloading.
#
# === Examples
#
# To download dotnet 4.0
#
#    download_file { "Download dotnet 4.0" :
#      url                   => 'http://download.microsoft.com/download/9/5/A/95A9616B-7A37-4AF6-BC36-D6EA96C8DAAE/dotNetFx40_Full_x86_x64.exe',
#      destination_directory => 'c:\temp',
#    }
#
# To download dotnet 4.0 using a proxy and extend operation timeout to 30000 seconds
#
#    download_file { "Download dotnet 4.0" :
#      url                   => 'http://download.microsoft.com/download/9/5/A/95A9616B-7A37-4AF6-BC36-D6EA96C8DAAE/dotNetFx40_Full_x86_x64.exe',
#      destination_directory => 'c:\temp',
#      proxy_address         => 'http://corporateproxy.net:8080',
#      timeout               => 30000,
#    }
#
define download_file(
  Stdlib::HTTPUrl $url,
  String $destination_directory,
  Optional[String] $destination_file                                          = undef,
  $proxy_address                                                              = undef,
  $user                                                                       = '',
  $password                                                                   = '',
  $proxy_user                                                                 = '',
  $proxy_password                                                             = '',
  $is_password_secure                                                         = true,
  Optional[Enum['ssl3', 'tls', 'tls11', 'tls12', 'tls13']] $security_protocol = undef,
  Optional[Integer] $timeout                                                  = undef,
  Optional[Array[String]] $cookies                                            = undef,
  Optional[String] $user_agent                                                = undef
) {

  if $destination_file {
    $filename = $destination_file
  } else {
    $filename = regsubst($url, '^http.*\/([^\/]+)$', '\1')
  }

  if $timeout {
    Exec { timeout => $timeout }
  }

  if $cookies {
    $cookie_string = join($cookies, ';')
  }

  $file_path = "${destination_directory}\\download-${filename}.ps1"

  file { "download-${filename}.ps1":
    ensure  => present,
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

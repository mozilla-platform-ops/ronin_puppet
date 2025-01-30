class packages::duo_unix (
  Pattern[/^\d+\.\d+\.\d+$/] $version = '1.11.4',
) {
  if $facts['os']['release']['major'] == '14' {
    packages::macos_package_from_s3 { 'duo_unix_mac14.pkg':
      type => 'pkg',
    }
  } else {
    packages::macos_package_from_s3 { "duo_unix-${version}.pkg":
      os_version_specific => true,
      type                => 'pkg',
    }
  }
}

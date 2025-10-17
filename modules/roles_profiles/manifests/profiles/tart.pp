# Installs Tart directly from Cirrus Labs GitHub releases,
# configures registry access, and sets up a LaunchDaemon
# so each macOS worker runs Tart automatically.

class roles_profiles::profiles::tart (
  String  $version        = lookup('tart.version', { default_value => 'latest' }),
  String  $registry_host  = lookup('tart.registry_host', { default_value => 'registry.local' }),
  Integer $registry_port  = lookup('tart.registry_port', { default_value => 5000 }),
  Boolean $insecure       = lookup('tart.insecure', { default_value => true }),
) {

  Exec {
    path => [
      '/opt/homebrew/bin',
      '/usr/local/bin',
      '/usr/bin',
      '/bin',
      '/usr/sbin',
      '/sbin',
    ],
  }

  require roles_profiles::profiles::homebrew_silent_install

  File <| title == '/opt/homebrew/bin' |> {
    owner => 'admin',
    group => 'admin',
    mode  => '0755',
  }

  # ---------------------------------------------------------------------------
  # Pick a specific Tart version to avoid "latest" redirect returning HTML
  # ---------------------------------------------------------------------------
  $tart_pkg_url = $version ? {
    'latest' => 'https://github.com/cirruslabs/tart/releases/download/0.58.0/tart.pkg',
    default  => "https://github.com/cirruslabs/tart/releases/download/${version}/tart.pkg",
  }

  # ---------------------------------------------------------------------------
  # Download the Tart .pkg with retries
  # ---------------------------------------------------------------------------
  exec { 'download_tart_pkg':
    command   => "/usr/bin/curl -fL --retry 5 --retry-delay 5 -o /var/tmp/tart-latest.pkg ${tart_pkg_url} && /bin/ls -lh /var/tmp/tart-latest.pkg",
    creates   => '/var/tmp/tart-latest.pkg',
    path      => ['/usr/bin','/bin'],
    logoutput => true,
  }

  # ---------------------------------------------------------------------------
  # Validate pkg and re-download automatically if too small
  # ---------------------------------------------------------------------------
  exec { 'validate_tart_pkg':
    command   => "/bin/bash -c \"size=\$(stat -f%z /var/tmp/tart-latest.pkg 2>/dev/null || echo 0); \
      if [ \${size:-0} -lt 100000 ]; then \
        echo 'Tart pkg too small ('\${size}' bytes) — retrying download'; \
        /bin/rm -f /var/tmp/tart-latest.pkg; \
        /usr/bin/curl -fL --retry 5 --retry-delay 5 -o /var/tmp/tart-latest.pkg ${tart_pkg_url}; \
      fi\"",
    unless    => 'test -x /opt/homebrew/bin/tart',
    path      => ['/usr/bin','/bin','/bin/bash'],
    require   => Exec['download_tart_pkg'],
    logoutput => true,
  }

  # ---------------------------------------------------------------------------
  # Install Tart from verified .pkg
  # ---------------------------------------------------------------------------
  exec { 'install_tart_direct':
    command   => '/usr/sbin/installer -verboseR -pkg /var/tmp/tart-latest.pkg -target / || (echo "Installer failed, removing pkg" && /bin/rm -f /var/tmp/tart-latest.pkg && exit 1)',
    creates   => '/opt/homebrew/bin/tart',
    path      => ['/usr/bin','/bin','/usr/sbin','/sbin'],
    unless    => 'test -x /opt/homebrew/bin/tart',
    require   => Exec['validate_tart_pkg'],
    logoutput => true,
    before    => [ File['/etc/tart_registry.conf'], File['/Library/LaunchDaemons/com.mozilla.tartworker.plist'] ],
    notify    => Exec['cleanup_tart_pkg'],
  }

  exec { 'cleanup_tart_pkg':
    command     => '/bin/rm -f /var/tmp/tart-latest.pkg',
    refreshonly => true,
    path        => ['/usr/bin','/bin'],
  }

  Exec['download_tart_pkg'] -> Exec['validate_tart_pkg'] -> Exec['install_tart_direct'] -> Exec['cleanup_tart_pkg']

  file { '/etc/tart_registry.conf':
    ensure  => file,
    content => "registry=${registry_host}:${registry_port}\ninsecure=${insecure}\n",
    owner   => 'root',
    group   => 'wheel',
    mode    => '0644',
    require => Exec['install_tart_direct'],
  }

  file { '/Library/LaunchDaemons/com.mozilla.tartworker.plist':
    ensure  => file,
    source  => 'puppet:///modules/roles_profiles/profiles/tartworker/com.mozilla.tartworker.plist',
    owner   => 'root',
    group   => 'wheel',
    mode    => '0644',
    require => Exec['install_tart_direct'],
  }
}

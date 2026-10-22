# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

## CLEAN UP: lookups should be in the profile and passed to this class.

# Python 3 needs a current certifi CA bundle (bug 1662170). pip vendors its own
# copy, so both are pinned by version and SHA-256 and upgraded when they differ.
class win_mozilla_build::install_py3_certs {
  require win_mozilla_build::install

  $python          = 'C:\\mozilla-build\\python3\\python3.exe'
  $pip_version     = lookup('windows.mozilla_build.py3_pip_version')
  $pip_url         = lookup('windows.mozilla_build.py3_pip_url')
  $pip_sha256      = lookup('windows.mozilla_build.py3_pip_sha256')
  $certifi_version = lookup('windows.mozilla_build.certifi_version')
  $certifi_url     = lookup('windows.mozilla_build.certifi_url')
  $certifi_sha256  = lookup('windows.mozilla_build.certifi_sha256')

  exec { 'upgrade_py3_pip':
    command  => "& '${python}' -m pip install --disable-pip-version-check 'pip @ ${pip_url}#sha256=${pip_sha256}'; exit \$LASTEXITCODE",
    unless   => "if ((& '${python}' -m pip --version) -match '^pip ${pip_version} ') { exit 0 } else { exit 1 }",
    provider => powershell,
  }

  exec { 'install_py3_certi':
    command  => "& '${python}' -m pip install --disable-pip-version-check 'certifi @ ${certifi_url}#sha256=${certifi_sha256}'; exit \$LASTEXITCODE",
    unless   => "if ((& '${python}' -c 'import certifi; print(certifi.__version__)') -eq '${certifi_version}') { exit 0 } else { exit 1 }",
    provider => powershell,
    require  => Exec['upgrade_py3_pip'],
  }
}

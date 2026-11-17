These unit definitions are maintained in Puppet rather than copied from the
service account's writable checkouts. Commands still run as `bitbar`.

Initial snapshots:

- `bitbar.service`, `bitbar-v3.service`: mozilla-bitbar-devicepool
  revision `9501f14fcb2a5dbe85b7c86e4f399eb83f064e93`.
- Alert and Influx logger units: android-tools revision
  `f207a2c053150d0ea6a50e07d8e9f35756706886`.

The three monitoring units retain `replace => 'no'` to preserve existing
operator configuration, including the last-started alert's PagerDuty token.
Before deployment, inspect those existing units and any systemd drop-ins:
confirm root ownership, no unprivileged write access, and `User=bitbar` with
no privileged execution directives. Do not copy their credentials into review
output. New installations receive the definitions here; existing files are not
automatically reset to these snapshots.

The last-started alert's shipped placeholder token must be configured before
enabling it, as before. Moving credentials to a separate root-managed file and
fully managing existing monitoring unit contents is a follow-up migration.

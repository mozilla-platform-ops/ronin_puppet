# Azure Utilities

## Scripts

- `kmsauditbase.ps1` runs against all windows virtual machines in azure and checks for license status using `license_check.ps1`
- `publicips.ps1` gets all azure public ips, filters them to just regions that run taskcluster worker images that are windows-based, and outputs just those.

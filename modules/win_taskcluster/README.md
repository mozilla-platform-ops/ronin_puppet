# Test a generic-worker source build on Windows

Set `windows.taskcluster.generic-worker.source_build` in the Windows worker-type
Hiera file on a test branch. The file is
`data/os/Windows/worker/<custom_win_gw_workertype>.yaml`.

For Taskcluster PR [#9162](https://github.com/taskcluster/taskcluster/pull/9162):

```yaml
windows:
  taskcluster:
    generic-worker:
      source_build:
        repository: jwmossmoz/taskcluster
        revision: 52807e9424f62f822e347025736e21bc519b4ce3
        go_version: 1.27.1
```

Build a Windows alpha image with `sourceBranch` set to that Puppet branch. The
worker-type name can be shared with production, so keep these settings on the
test branch. Without this setting, Puppet installs the configured release.

The build uses `multiuser` and the worker architecture (amd64 or arm64). It checks
the Go archive checksum and writes the source commit and binary hash to
`generic-worker.exe.source-build.json`. An existing release does not skip the
build. A later Puppet run skips the build only if the settings, script, and binary
match the saved record. Remove the setting to restore the configured release.

On the test VM, check that record, then configure `preloadedDirectoryCaches` in
the alpha worker config. Run two tasks on the same worker: read and change a seed
file in the first task, then check the change in the second. Repeat after a worker
restart and cache purge. Test with the seed and cache on different volumes too.

Run the local script checks with:

```powershell
pwsh -File test/unit/generic-worker-source-build.ps1
```

Windows execution and FXCI validation are still required. Use the latest autoland
decision builds. All tier 1 tasks must pass before production use.

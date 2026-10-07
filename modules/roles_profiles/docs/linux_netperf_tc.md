# Netperf traffic control

The netperf worker profiles install `/usr/local/bin/netperf-tc` and grant
`cltbld` passwordless sudo access to that wrapper. It is the only permitted
sudo interface for applying netperf traffic shaping.

## Interface

Run one of these commands as `cltbld`:

```sh
sudo -n /usr/local/bin/netperf-tc check
sudo -n /usr/local/bin/netperf-tc reset
sudo -n /usr/local/bin/netperf-tc apply BANDWIDTH_MBIT DELAY_MS LOSS tcp|udp PORT
```

`check` verifies that the system `tc` executable is available. `reset` removes
the root queueing discipline from loopback. `apply` first resets loopback, then
creates an HTB queueing discipline with a netem delay and optional loss rule.
Traffic matching the given TCP or UDP port is shaped for both IPv4 and IPv6,
in both source and destination directions.

`BANDWIDTH_MBIT` must be greater than zero and at most 10,000. `DELAY_MS` must
be between zero and 60,000. Both allow at most three decimal places. `LOSS`
must be a percentage between zero and 100, and `PORT` must be an integer from
1 through 65,535. Invalid input is rejected before running `tc`.

## Scope and safety

The wrapper uses fixed `/sbin/tc` invocations and only changes the `lo`
interface. It does not accept arbitrary `tc` arguments, interfaces, shell
syntax, or command paths. The direct `/sbin/tc` sudo grant is deliberately
absent after the Firefox caller migration.

## Firefox integration

The Firefox netperf caller uses `check`, `apply`, and `reset` to configure and
clean up its loopback shaping. It must call `reset` on normal cleanup and after
a failed setup so shaping does not affect later tasks.

## Checks

```sh
pre-commit run --files modules/linux_packages/files/netperf-tc \
  modules/linux_packages/manifests/netperf_tc.pp \
  test/integration/linux-netperf/inspec/sudoers_spec.rb
```

Kitchen's Linux netperf suite checks that the wrapper is installed with the
expected ownership and mode, and that sudo permits the wrapper but not direct
`/sbin/tc` access.

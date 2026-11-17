# Local test access

Run Kitchen commands from the repository root. Docker configuration generates
an Ed25519 key pair in `.kitchen/ssh/` on first evaluation, including direct
`KITCHEN_YAML=.kitchen_configs/kitchen.docker.yml bundle exec kitchen ...` calls
in CI. No manual key-generation step is needed. The directory is private, ignored
by Git and excluded from Docker build contexts; the private key is mode 0600.
Concurrent configuration loads use a file lock and reuse the same identity.
Separate checkouts and fresh CI jobs generate different identities.

Keep that directory while its test instances exist. Deleting the private key
creates a new identity on the next configuration load, requiring recreation of
instances built with the previous key. A missing public half is repaired from
the existing private key without changing the identity.

Existing Docker instances and images retain the previous shared public key.
Recreate them to use the new local identity. Existing `.kitchen/*.yml` state may
still reference the removed key; fresh instances are needed to test this change.
The source update does not change running instances.

The Vagrant configuration uses Vagrant's per-machine key insertion rather than
the former repository key. Its box bootstrap identity is still used for initial
provisioning; `c.ssh.insert_key = true` requests replacement with a generated key.

Ubuntu production sudoers omit the `kitchen` and `%vagrant` passwordless grants.
The sudo module adds those grants in a separate concat fragment only when the
`running_in_test_kitchen` fact is the boolean `true`. Docker, Vagrant and the
legacy CircleCI Kitchen configurations supply that provisioning fact. Absent,
false or string-valued facts do not enable the grants. Kitchen must continue
supplying the fact on each convergence so its test login retains sudo access.

The production RelOps and admin grants are unchanged. The broader macOS admin
grant from F88 needs a separate automation dependency review.

Focused local checks:

```sh
ruby test/test_kitchen_ssh.rb
ruby test/test_kitchen_sudo.rb  # requires Puppet and installed r10k modules
```

Validate the migration with a fresh Kitchen convergence followed by SSH and sudo
checks. Container privileges and port bindings stay as configured today.

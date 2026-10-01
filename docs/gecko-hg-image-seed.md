# Gecko Hg image seed (WIP)

The companion [worker-images PR #992](https://github.com/mozilla-platform-ops/worker-images/pull/992)
builds an opt-in Gecko Hg history seed for Windows cloud and Linux images.
Hardware WIMs, Git, and package caches are outside this WIP.

Puppet keeps its existing job: install Mercurial and robustcheckout, set
`HG_CACHE`, and manage shared-store permissions. Image creation does the large
download and reports its progress. Puppet does not download the history or
write Generic Worker's live `directory-caches.json`.

For Windows cloud images in this WIP, use `windows_task_drive: 'C:'`.
The current C: roles set `HG_CACHE=C:\hg-cache` and create `C:\hg-shared`.
The existing Everyone ACL lets successive task users update shared history.
Both the image-build and boot-time ACL resources keep SYSTEM as the directory
owner. The image builder restores inherited ACLs on the newly created store.

Windows x64 tasks use this shared pool directly. Windows ARM64 tasks use
`build/hg-store` inside a named checkout cache, so worker-images creates the
initial cache state. Generic Worker grants task-user access when it mounts it.
No new Puppet setting or background download service is needed.

This replaces the pip prototype. It removes the hardware-alpha cache lists
and the Puppet-generated cache state. Keep both PRs in draft until cloud-image
tests pass. Do not apply this as an in-place cache migration; test on fresh
images. No fxci-config pool paths or production image pins change in this PR.

# 🎁 Claude Handoff — PR #1152 + SimpleMDM Bootstrap

**Date:** 2026-05-15
**Authors:** Ryan Curran + Claude (Opus 4.7)
**Branch:** `sip-compatible-safari-automation`
**Pick-up window:** next week

Hello! 👋 If you're reading this, you have inherited the SIP-compatible
Safari Remote Automation saga. Here's where today left things and what
to chase next. Buckle up. 🎢

---

## 🗺️ The big picture

PR #1152 (`sip-compatible-safari-automation`) replaces the bash-wrapped
osascript Safari-enable dance with a **LaunchAgent that runs osascript
directly**, plus a **SimpleMDM-delivered PPPC mobileconfig** for
system-level TCC grants.

**End goal:** zero-touch DEP enrollment → puppet → worker live in TC,
on SIP-enabled macOS 15.3 M4 Mac minis, without the human ever SSHing
in. ✨

---

## ✅ What got validated today on macmini-m4-118 (`gecko_t_osx_1500_m4_staging`)

| Path | Status |
|---|---|
| 🟢 In-place pivot from existing puppet state to PR branch | green |
| 🟢 Fresh post-EACS + admin VNC + SSH-driven bootstrap | green |
| 🟢 **Fresh post-EACS + admin VNC + SimpleMDM-driven bootstrap (2nd EACS round)** | **green — visually confirmed in cltbld VNC: Develop menu present + "Allow remote automation" checked.** Ryan eyeballed Safari → Settings → Developer. The earlier silent-skip on first MDM run is fixed by the verify-after-click commit on this branch. |
| 🔐 Bootstrap Token custody stays on `admin` (cltbld DISABLED) | confirmed via `sysadminctl -secureTokenStatus` + APFS crypto users |
| 🪪 PPPC FDA grants for `/bin/bash` + `/usr/bin/sqlite3` land on host | confirmed via `/Library/Managed Preferences/com.apple.TCC.configuration-profile-policy.plist` |
| 🧪 Try-push validation on real CI tasks | in flight at time of writing: https://treeherder.mozilla.org/jobs?repo=try&landoInstance=lando-prod-2025&landoCommitID=47137 — `'test-macosx1500-aarch64 'mochitest-plain` with worker-override to staging pool, other staging hosts quarantined so everything serializes on m4-118 |

> The bug that hid the silent-skip from us on the *first* round was the
> semaphore-on-success-without-actual-success behavior. 🫠 The
> verify-after-click commit (4bf1b8bf/85876cc5) makes the script
> error out if either of the two checkbox values is not 1 after the
> click, so a stuck toggle surfaces as a puppet failure and the
> SimpleMDM driver's outer retry loop tries again instead of declaring
> victory. EACS round 2 hit this clean path.

---

## 🪤 The footguns I left in the sand for you

1. **🔒 PPPC FDA for sshd alone is NOT enough.** A LaunchDaemon-spawned
   puppet hits `authorization denied` writing cltbld's user TCC DB,
   even with `/bin/bash` + `/usr/bin/sqlite3` FDA grants present. The
   bootstrap driver routes `run-puppet.sh` through `ssh root@localhost`
   so puppet inherits sshd's user-session TCC domain. One-shot ed25519
   key at `/var/root/.ssh/bootstrap_id_ed25519` during bootstrap,
   removed on sentinel write. This lives in the in-tree bootstrap
   script (`modules/macos_safaridriver/simplemdm-bootstrap-sip-safari.sh`)
   — when we evolve this, the workaround should probably move into
   a real puppet/PR change.

2. **🐚 `launchctl asuser 0 <cmd>` does NOT escape the system domain
   when invoked from a LaunchDaemon.** It only actually transitions
   when the caller is already in a user-session domain (sshd-spawned,
   GUI login). I burned an embarrassing amount of time today before
   pivoting to ssh-to-localhost. Save yourself. 😅

3. **🌐 LaunchDaemon RunAtLoad fires before DNS is up at boot.** First
   puppet tick on a freshly-rebooted host died on `git fetch`'s DNS
   lookup and our one-shot LaunchDaemon never retried. Driver now waits
   on `dscacheutil` resolving `github.com` before doing anything, with
   an outer while-loop retrying `run-puppet.sh` until both semaphores
   land.

---

## 📦 Artifacts worth bookmarking (all in-tree)

| Path | What it is |
|---|---|
| [`modules/macos_safaridriver/simplemdm-bootstrap-sip-safari.sh`](./simplemdm-bootstrap-sip-safari.sh) | The SimpleMDM script. Upload as a script-job, run-on-enrollment, scoped to the M4 staging group. Idempotent, self-cleans on success. |
| [`modules/macos_mobileconfig_profiles/files/org.mozilla.ci-tcc-pppc.mobileconfig`](../macos_mobileconfig_profiles/files/org.mozilla.ci-tcc-pppc.mobileconfig) | The PPPC mobileconfig. Upload to SimpleMDM as a Custom Configuration Profile, replacing the previous "Mozilla CI TCC Permissions". Has the new bash + sqlite3 FDA grants this branch added. |
| [`modules/macos_safaridriver/files/safari-enable-remote-automation.applescript`](./files/safari-enable-remote-automation.applescript) | The applescript with the new defensive verify. |

---

## 🚧 Remaining work for actual zero-touch

- **🔑 vault.yaml delivery.** Still a manual scp/drop step. Bootstrap
  script polls `/var/root/vault.yaml` up to 10 min. Open question:
  secure-fetch via an internal endpoint? SimpleMDM Custom Attribute
  with the file body? Something else? Pick whichever path fits next.

- **👤 admin VNC login** is still required to plant the Bootstrap Token
  before puppet flips autologin to cltbld. No known mechanism to script
  a GUI/console login during DEP / Setup Assistant. If you find one,
  you become a legend. 🏆

- **🖋️ start-worker / generic-worker-multiuser** need Developer ID
  signing to be coverable by the PPPC profile (ScreenCapture
  specifically). `start-worker` is currently a user-DB fallback entry
  in `tcc_perms.sh`. This is a long-standing open issue upstream:
  [taskcluster/taskcluster#7413](https://github.com/taskcluster/taskcluster/issues/7413)
  — worth noting on this PR but not blocking it.

---

## 🔬 Verification method

The gold standard is opening Safari in cltbld's VNC session and visually
confirming:

- Develop menu is in the menu bar
- Safari → Settings → Developer → "Allow remote automation" is checked

This is the dance the RelOps team has been doing since macOS 10.15. 🕺

---

## 🚀 Recommended reorientation playbook

1. Read this file, the mobileconfig, and the in-tree bootstrap script linked above.
2. EACS macmini-m4-118 (or any spare staging M4).
3. Admin VNC login → drop `vault.yaml` → trigger the SimpleMDM script.
4. Once bootstrap completes (sentinel `/var/log/m4-bootstrap-complete`),
   eyeball Safari → Settings → Developer in cltbld's VNC session.
5. If anything is weird, `/var/log/m4-bootstrap.log` (one-shot setup)
   and `/var/log/m4-bootstrap-driver.log` (boot-by-boot puppet) are
   your friends 🪵. SSH keys and LaunchDaemon plists self-clean on
   success; if they're still on disk, the driver hasn't declared
   victory yet.

---

Good luck. May your AppleScript clicks actually persist. 🍀

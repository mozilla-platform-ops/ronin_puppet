# README_2404_dev.md

Documents the development process for 2404 X11.

## how 1804 works

1. start Xorg x11 server as root (x11vnc points at this)
2. start gnome Xssession on Xorg server
3. cltbld user autostarts gnome-terminal that runs start-worker-runner-wrapper

## 2404 things tried

### xorg with Xsession (like 1804)

1. start Xorg x11 server as root (x11vnc points at this)
2. start gnome Xssession on Xorg server
3. cltbld user autostarts gnome-terminal that runs start-worker-runner-wrapper

problems:
  - have to bring our own dbus, systemd, logind daemons and configurations to ensure that all of the components can talk to services they need to talk to to make a fully functional desktop.
    - 2404's gnome has become more interdependent on these services and it's harder to simulate a real desktop environment.
      - why can't we just run a normal setup? how is our environment is different from a normal user's?
        - no attached display
        - datacenter concerns: don't want to run on default VGA (security concern?)
          - is this why 18.04 runs on it's own X server vs the default one?
          - does windows worry about this?
            - they're connected to KVM... so physical attacker could access/interact with sessions.
            - seems like it shouldn't be a concern for linux.

current problems: can get it to boot up what looks like a barebones gnome session (apps won't launch though), but not a full ubuntu desktop. tons of errors in the gnome-session logs about not being able to contact services. indicative of session without logind, pam, etc permissions/connections setup.

#### how do the cloud wayland images handle this?

g-w multi uses gdm to do autologin.

why is 2404 hardware is harder?
- GPU?
- need simple/insecure g-w for talos perf (until we implement and test out g-w multi single user)

### gdm-launched gnome

1. start gdm
2. gdm autologins the cltbld user
3. cltbld user autostarts gnome-terminal that runs start-worker-runner-wrapper

current problems: can't get x11vnc working to see if it's working.

### plain old gdm on main display

Discussed with windows team and no security concern running on the main VGA output (actually required to use KVMs). Seems to just work as expected. Need to figure out x11, but should be ok.

## final implementation

We use the plain old gdm on the main display.

#!/usr/bin/env python3

import argparse
import os
import sys
import syslog

import pendulum
import psutil

# pseudocode for check_gw
# - colord xsession workaround didn't seem to work
#
# if date bad
#   fix date
# if load_zero and no_generic_worker and uptime_15min:
#   reboot
#
# a result code of: 5: host in bad state, rebooting
#                   3: clock fixing done
#                   0: everything ok
#                   others: error

# problematic scenarios currently:
#   - operator hold
#       - TODO: check for operator_hold... if present, don't do anything
#   - test kitchen testing
#       - check to see if puppet role set in /etc/puppet_role
#       - meh... 15 minutes is fine for testing...?
#           - if not, use operator hold

# TODO: telegraf event logging (if clock fixed, if rebooted).

def is_sys_date_ok():
    n = pendulum.now()
    if n.year >= 2020:
        return True
    return False


def is_in_operator_hold():
    # TODO: template the operator hold path in
    if os.path.exists('/home/cltbld/operator_hold'):
        return True
    return False


def is_puppet_role_set():
    # TODO: template the puppet role path in
    if os.path.exists('/etc/puppet_role'):
        return True
    return False


def fix_sys_date():
    # get clock synced. if clock is way off, run-puppet.sh will never finish
    # it's git clone because the SSL cert will appear invalid.
    os.system("/etc/init.d/ntp stop > /dev/null 2>&1")
    os.system("ntpd -q -g")  # runs once and force allows huge skews
    os.system("/etc/init.d/ntp start > /dev/null 2>&1")

    # now check that it's ok or raise
    if not is_sys_date_ok():
        print("couldn't get system datetime synced to reality!")
        sys.exit(1)

    # should we reboot here?
    # print("system clock fixed. rebooting...")
    # reboot_system()

    # exit non-zero, we'll get the host next pass
    # sys.exit(3)

    # delay exit
    return 3


def get_boot_time():
    return pendulum.from_timestamp(psutil.boot_time())


def find_procs_by_name(name):
    "Return a list of processes matching 'name'."
    ls = []
    for p in psutil.process_iter(["name", "exe", "cmdline"]):
        if (
            name == p.info["name"]
            or p.info["exe"]
            and os.path.basename(p.info["exe"]) == name
            or p.info["cmdline"]
            and p.info["cmdline"][0] == name
        ):
            ls.append(p)
    return ls


# looks for the name in the full command line argument (vs just the name)
def find_procs_by_cmdline(name):
    "Return a list of processes matching 'name'."
    ls = []
    for p in psutil.process_iter(["cmdline"]):
        # print(p)
        if p.info["cmdline"]:
            for item in p.info["cmdline"]:
                # print(item)
                if name in item:
                    ls.append(p)
    return ls


def reboot_system():
    cmd = "sleep %s && reboot" % seconds_before_reboot
    # orig
    # os.system(cmd)
    # try to have script return before the reboot occurs
    os.system("nohup bash -c '%s' &" % cmd)


if __name__ == "__main__":
    rc = 0
    load_low = False
    proc_present = False
    uptime_high = False

    parser = argparse.ArgumentParser(
        description="check talos worker health and reboot if needed."
    )
    parser.add_argument(
        "--reboot",
        action="store_true",
        default=False,
        help="do the reboot if the host is bad",
    )
    args = parser.parse_args()

    if not is_sys_date_ok():
        print("Host clock is bad. Fixing...")
        rc = fix_sys_date()

    if not is_puppet_role_set():
        print("No puppet role set. Exiting...")
        sys.exit(rc)

    if is_in_operator_hold():
        print("Host in operator_hold mode. Exiting...")
        sys.exit(rc)

    # rsw_procs = find_procs_by_cmdline("run-start-worker.sh")
    # print("rsw process: %s" % rsw_procs)
    gw_procs = find_procs_by_name("generic-worker")
    print("gw process: %s" % gw_procs)
    if len(gw_procs) == 1:
        proc_present = True
    elif len(gw_procs) > 1:
        raise Exception("strange")

    #
    uptime_minutes = (pendulum.now() - get_boot_time()).in_minutes()
    print("uptime: %s minutes" % uptime_minutes)
    if uptime_minutes > 15:
        uptime_high = True

    #
    load1, load5, load15 = os.getloadavg()
    load_sum = load1 + load5 + load15
    print("load1, 5, 15: %s %s %s" % (load1, load5, load15))
    print("load sum: %s" % load_sum)
    if load1 <= 0.2:
        load_low = True

    print("--")
    if uptime_high and load_low and not gw_procs:
        if args.reboot:
            seconds_before_reboot = 10
            this_script = os.path.basename(__file__)
            # wall fails with: 'wall: cannot get tty name: Inappropriate ioctl for device'
            # os.system(
            #     "wall '%s: Failure to launch generic-worker detected. Rebooting in %s seconds...'"
            #     % (this_script, seconds_before_reboot)
            # )

            # write to syslog
            # the argument to openlog() is the topic
            syslog.openlog(this_script)
            msg = (
                "Failure to launch generic-worker detected. Rebooting in %s seconds...'"
                % seconds_before_reboot
            )
            syslog.syslog(msg)

            print("BAD HOST: rebooting in %s seconds..." % seconds_before_reboot)
            reboot_system()
        else:
            print("BAD HOST: recommend rebooting")
        sys.exit(5)
    else:
        print("host seems ok")

    sys.exit(rc)

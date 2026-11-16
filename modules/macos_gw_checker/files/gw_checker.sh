#!/bin/bash

# Reboots the worker when generic-worker isn't running and the host won't recover on its own.

WEDGED_STATE=/var/tmp/gw_checker.wedged
MIN_UPTIME_SECONDS=900

log() {
    echo "$1"
    logger -t gw_checker "$1"
}

# Check if the semaphore file exists
if [ ! -f /var/tmp/semaphore/run-buildbot ]; then
    echo "Semaphore file /var/tmp/semaphore/run-buildbot does not exist. Exiting script."
    exit 1
fi

# Leave a freshly booted host alone while worker-runner starts up
boot_time=$(sysctl -n kern.boottime | sed -E 's/^\{ sec = ([0-9]+),.*/\1/')
uptime_seconds=$(( $(date +%s) - boot_time ))
if [ "$uptime_seconds" -lt "$MIN_UPTIME_SECONDS" ]; then
    echo "Up for ${uptime_seconds}s, too early to check."
    exit 0
fi

# Check if /bin/bash, /usr/local/bin/worker-runner.sh, and /opt/worker/worker-runner-config.yaml are running
check_processes() {
    if ! pgrep -x "bash" > /dev/null; then
        return 1
    fi

    if ! pgrep -f "/usr/local/bin/worker-runner.sh" > /dev/null; then
        return 1
    fi

    if ! pgrep -f "/opt/worker/worker-runner-config.yaml" > /dev/null; then
        return 1
    fi

    return 0
}

# When generic-worker exits or aborts (seen with exit code 69 and with
# "fakecgo: pthread_create failed: 35"), start-worker can stay alive with no child and never
# exit, so worker-runner.sh never reaches its reboot.
# Reboot only if the same start-worker has had no child on two checks in a row.
check_wedged_worker() {
    local sw_pid
    sw_pid=$(pgrep -x start-worker | head -1)

    if [ -z "$sw_pid" ] || pgrep -P "$sw_pid" > /dev/null; then
        rm -f "$WEDGED_STATE"
        return 0
    fi

    if [ "$(cat "$WEDGED_STATE" 2>/dev/null)" = "$sw_pid" ]; then
        rm -f "$WEDGED_STATE"
        return 1
    fi

    echo "$sw_pid" > "$WEDGED_STATE"
    log "start-worker (pid ${sw_pid}) has no generic-worker child. Rebooting if that is still true on the next check."
    return 0
}

# Main script
if ! check_processes; then
    log "One or more required processes are not running. Rebooting the machine..."
    /sbin/reboot
elif ! check_wedged_worker; then
    log "start-worker has had no generic-worker child for two checks in a row. Rebooting the machine..."
    /sbin/reboot
else
    echo "All required processes are running."
fi

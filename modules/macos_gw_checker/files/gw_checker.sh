#!/bin/bash

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

# Main script
if ! check_processes; then
    echo "One or more required processes are not running. Rebooting the machine..."
    sudo reboot
else
    echo "All required processes are running."
fi

#!/bin/bash

# hyprlock-nvidia-fix.sh — simple restart of hypridle without using systemd
#
# This script restarts the hypridle daemon by killing any existing
# instance and launching a new one.  It is intended to be used in
# setups where systemd services are not desirable or available.  The
# script can be invoked without elevated privileges.

# Terminate any running hypridle instance.  Ignore errors if
# hypridle is not running.
if pgrep -x hypridle >/dev/null 2>&1; then
    pkill -x hypridle || true
    # Give hypridle some time to shut down cleanly
    sleep 0.5
    exit 0
fi

# Relaunch hypridle in the background.  Use `nohup` and redirect
# output to /dev/null so that the process detaches from the current
# shell and doesn’t hold up the caller.
nohup hypridle >/dev/null 2>&1 &

exit 0

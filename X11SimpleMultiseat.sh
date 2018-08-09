#!/usr/bin/env bash
CHILD_USER=${CHILD_USER:-tobias}
RESOLUTION=${RESOLUTION:-1920x1080}

set -x 
#fullscreen seems to take full width of X11 and ignore "-screen"
MOUSE=${MOUSE:-/dev/input/by-path/pci-0000:00:14.0-usb-0:5.4.2:1.0-event-mouse}
KEYBOARD=${KEYBOARD:-/dev/input/by-path/pci-0000:00:14.0-usb-0:5.4.1:1.0-event-kbd}
DISP_NUM=${DISP_NUM:-2}

sudo Xephyr :$DISP_NUM -keybd evdev,,device=${KEYBOARD},xkbrules=evdev,xkbmodel=evdev -mouse evdev,,device=${MOUSE} -dpi 96 -retro -no-host-grab -softCursor -screen $RESOLUTION +extension GLX &
export PID=$!

export DISPLAY=:$DISP_NUM
sudo su --login -c ecryptfs-mount-private ${CHILD_USER}
sudo su --login -c xfce4-session ${CHILD_USER}

sleep 1
sudo kill $(ps --ppid ${PID} -o pid=)


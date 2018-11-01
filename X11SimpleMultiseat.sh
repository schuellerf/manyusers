#!/usr/bin/env bash
CHILD_USER=${CHILD_USER:-tobias}
RESOLUTION=${RESOLUTION:-1920x1080}

set -xe


# for Virtual GL checkout:
# https://virtualgl.org/Documentation/Documentation
# to install VirtualGL.
# then start your application in Xephyr with:
# /opt/VirtualGL/bin/vglrun -- <your opengl application>

if /opt/VirtualGL/bin/glxinfo -display :0 -c|grep -P "P[^ ]*$" >/dev/null; then
	echo "Virtual GL seems to be active - allowing user access"
	xhost +LOCAL:
fi

#fullscreen seems to take full width of X11 and ignore "-screen"
MOUSE=${MOUSE:-/dev/input/by-path/pci-0000:00:14.0-usb-0:5.4.2:1.0-event-mouse}
KEYBOARD=${KEYBOARD:-/dev/input/by-path/pci-0000:00:14.0-usb-0:5.4.1:1.0-event-kbd}
DISP_NUM=${DISP_NUM:-2}

sudo Xephyr :$DISP_NUM -resizeable -keybd evdev,,device=${KEYBOARD},xkbrules=evdev,xkbmodel=evdev -mouse evdev,,device=${MOUSE} -dpi 96 -retro -no-host-grab -softCursor -screen $RESOLUTION +extension GLX &
export PID=$!

export DISPLAY=:$DISP_NUM
# mount ecryptfs only if necessary
if [ -d /home/.ecryptfs/${CHILD_USER} ]; then
	sudo ecryptfs-verify -e -u ${CHILD_USER} 2>/dev/null && sudo su --login -c ecryptfs-mount-private ${CHILD_USER}
fi
sudo su --login -c "dbus-launch --exit-with-session xfce4-session" ${CHILD_USER}

sleep 1
sudo kill $(ps --ppid ${PID} -o pid=)


#!/usr/bin/env bash

# select a user if CHILD_USER is not set
if [ -z "$CHILD_USER" ]; then
	echo -e "\nSelect a CHILD_USER, please:"
	select CHILD_USER in $(ls /home); do
		break
	done
fi
[ -z "$CHILD_USER" ] && echo "No user selected" && exit 1
echo Starting for $CHILD_USER ...
RESOLUTION=${RESOLUTION:-1920x1080}

set -e


# for Virtual GL checkout:
# https://virtualgl.org/Documentation/Documentation
# to install VirtualGL.
# then start your application in Xephyr with:
# /opt/VirtualGL/bin/vglrun -- <your opengl application>

if /opt/VirtualGL/bin/glxinfo -display :0 -c|grep -P "P[^ ]*$" >/dev/null; then
	echo "Virtual GL seems to be active - allowing user access"
	xhost +LOCAL:
fi

get-free-display(){
    declare -a displays
    # find all Xephyr instances and loop through them
    while read line; do
        # this lists the actual command that is running, and replaces
        # the \x00 with a space
        var="$(cat /proc/$line/cmdline | sed -e 's/\x00/ /g'; echo)"
        # loop through the string
        for word in $var; do
            # if it matches a regex, output the number of the display
            if [[ $word =~ ^:[0-9] ]]; then
                displays+=("${word/:/}")
            fi
        done
    done <<< "$(pgrep -f Xephyr)"
    # the initial one
    display=1
    while true; do
        for d in "${displays[@]}"; do
            if [[ "$display" == "$d" ]]; then
                display=$(( $display + 1 ))
            fi
        done
        echo $display
        return 0
    done
}

#fullscreen seems to take full width of X11 and ignore "-screen"
MOUSE=${MOUSE:-/dev/input/by-path/pci-0000:00:14.0-usb-0:5.4.2:1.0-event-mouse}
KEYBOARD=${KEYBOARD:-/dev/input/by-path/pci-0000:00:14.0-usb-0:5.4.1:1.0-event-kbd}

[ -z "$DISP_NUM"] && DISP_NUM=$(get-free-display)

sudo Xephyr :$DISP_NUM -resizeable -keybd evdev,,device=${KEYBOARD},xkbrules=evdev,xkbmodel=evdev -mouse evdev,,device=${MOUSE} -dpi 96 -retro -no-host-grab -softCursor -screen $RESOLUTION +extension GLX &
export PID=$!

export DISPLAY=:$DISP_NUM
# mount ecryptfs only if necessary
if [ -d /home/.ecryptfs/${CHILD_USER} ]; then
	sudo ecryptfs-verify -e -u ${CHILD_USER} 2>/dev/null && sudo su --login -c ecryptfs-mount-private ${CHILD_USER}
fi

sudo bash -c "cp -f /home/\${SUDO_USER}/.config/pulse/cookie /home/${CHILD_USER}/.Xephyr_pa_cookie"
sudo chown ${CHILD_USER}:  /home/${CHILD_USER}/.Xephyr_pa_cookie

PULSE_SERVER=127.0.0.1
PULSE_COOKIE=/home/${CHILD_USER}/.Xephyr_pa_cookie

if ! pacmd list-modules |grep module-native-protocol-tcp >/dev/null; then
	pacmd load-module module-native-protocol-tcp
fi

set -x
sudo su --login -c "PULSE_SERVER=$PULSE_SERVER PULSE_COOKIE=$PULSE_COOKIE dbus-launch --exit-with-session xfce4-session" ${CHILD_USER}

sleep 1
sudo kill $(ps --ppid ${PID} -o pid=)


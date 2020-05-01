#!/usr/bin/env bash
CHILD_USER=${CHILD_USER:-tobias}
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

set +x 
PA_LIST=( $(pacmd list-sinks|grep -Po "(?<=name: <).*(?=>)") )
PA_SRC_LIST=( $(pacmd list-sources|grep -Po "(?<=name: <).*(?=>)"|grep -v "\\.monitor") )

if [ ${#PA_LIST[*]} -eq 1 ] ; then
	PA_NAME=${PA_LIST[0]}
	echo "Found good pulse audio name: $PA_NAME"
else

	echo "----"
	I=0
	for n in ${PA_LIST[*]}; do
		echo "$I: $n"
		I=$(( $I + 1 ))
	done
	read -p "Please select a sound output: " IDX

	PA_NAME=${PA_LIST[$IDX]}
	echo "You selected: $PA_NAME"
fi

if [ ${#PA_SRC_LIST[*]} -eq 1 ] ; then
	PA_SRC_NAME=${PA_SRC_LIST[0]}
	echo "Found good pulse audio name: $PA_SRC_NAME"
else

	echo "----"
	I=0
	for n in ${PA_SRC_LIST[*]}; do
		echo "$I: $n"
		I=$(( $I + 1 ))
	done
	read -p "Please select a sound input: " IDX

	PA_SRC_NAME=${PA_SRC_LIST[$IDX]}
	echo "You selected: $PA_SRC_NAME"
fi

sudo Xephyr :$DISP_NUM -resizeable -keybd evdev,,device=${KEYBOARD},xkbrules=evdev,xkbmodel=evdev -mouse evdev,,device=${MOUSE} -dpi 96 -retro -no-host-grab -softCursor -screen $RESOLUTION +extension GLX &
export PID=$!

export DISPLAY=:$DISP_NUM
# mount ecryptfs only if necessary
if [ -d /home/.ecryptfs/${CHILD_USER} ]; then
	sudo ecryptfs-verify -e -u ${CHILD_USER} 2>/dev/null && sudo su --login -c ecryptfs-mount-private ${CHILD_USER}
fi

sudo bash -c "cp -f /home/\${SUDO_USER}/.config/pulse/cookie /home/${CHILD_USER}/.Xephyr_pa_cookie"
sudo chown ${CHILD_USER}  /home/${CHILD_USER}/.Xephyr_pa_cookie

sudo su --login -c "pactl load-module module-tunnel-sink \"server=127.0.0.1 sink=$PA_NAME sink_name=local_sound cookie=/home/${CHILD_USER}/.Xephyr_pa_cookie\"" ${CHILD_USER}
sudo su --login -c "pactl load-module module-tunnel-source \"server=127.0.0.1 source=$PA_SRC_NAME source_name=local_in_sound cookie=/home/${CHILD_USER}/.Xephyr_pa_cookie\"" ${CHILD_USER}

set -x
sudo su --login -c "dbus-launch --exit-with-session xfce4-session" ${CHILD_USER}

sleep 1
sudo kill $(ps --ppid ${PID} -o pid=)


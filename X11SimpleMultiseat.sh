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

set +x 
PA_LIST=( $(pacmd list-sinks|grep -Po "(?<=name: <).*(?=>)") )

if [ ${#PA_LIST[*]} -eq 1 ] ; then
	PA_NAME=${PA_LIST[0]}
	echo "Found good pulse audio name: $PA_NAME"
else
	# found multiples
	PA_LIST=( $(pacmd list-sinks|grep -Po "(?<=name: <).*(?=>)") )

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

set -x
sudo su --login -c "dbus-launch --exit-with-session xfce4-session" ${CHILD_USER}

sleep 1
sudo kill $(ps --ppid ${PID} -o pid=)


#!/usr/bin/env bash

UBUNTU_PACKAGES="xserver-xephyr evtest"

for package in ${UBUNTU_PACKAGES}; do
  if ! apt list --installed 2>/dev/null|grep "^$package" >/dev/null; then
      sudo apt install -y $package
  fi
done

sudo rm -rf /tmp/test-fifo
mkfifo /tmp/test-fifo
check() {
	sudo evtest $1 2>/dev/null|grep --line-buffered "^Event: "|dd bs=100 count=1 >/dev/null 2>&1 && echo "$1" >> /tmp/test-fifo
}

declare -a pids
echo -n "Starting keyboard & mouse listeners... "
for e in $( ls /dev/input/by-path/*event-kbd* /dev/input/by-path/*event-mouse* ); do
	check $e >/dev/null 2>&1 &
	p=$(ps --ppid $! -o pid=)
	pids+=("$p")
done
echo "done"

echo -e "\nPlease move the mouse"
export MOUSE=$(cat /tmp/test-fifo|grep -m 1 "/dev/input/.*")
echo "The mouse is $MOUSE"


echo -e "\nPlease press <Ctrl> two or three times"
export KEYBOARD=$(cat /tmp/test-fifo|grep -m 1 "/dev/input/.*")
echo "The keyboard is $KEYBOARD"

echo Thank you

sleep 1

echo -n "Stopping keyboard & mouse listeners... "
#sudo kill ${pids[*]} >/dev/null 2>&1
sudo killall evtest
wait ${pids[*]} >/dev/null 2>&1
echo "done"

sudo rm -rf /tmp/test-fifo

echo "Let's go"
$(dirname $0)/X11SimpleMultiseat.sh

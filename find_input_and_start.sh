#!/usr/bin/env bash

sudo apt install xserver-xephyr evtest

sudo rm -rf /tmp/test-fifo
mkfifo /tmp/test-fifo
check() {
	sudo evtest $1|grep --line-buffered "^Event: "|dd bs=100 count=1 >/dev/null 2>&1 && echo "$1" >> /tmp/test-fifo
}

declare -a pids
echo "Starting listeners"
for e in $( ls /dev/input/event* ); do
	check $e >/dev/null 2>&1 &
	p=$(ps --ppid $! -o pid=)
	pids+=("$p")
done
echo "done"

echo "Please move the mouse"
export MOUSE=$(cat /tmp/test-fifo|grep -m 1 "/dev/input/.*")


echo "Please press Ctrl often"
export KEYBOARD=$(cat /tmp/test-fifo|grep -m 1 "/dev/input/.*")

echo Thank you

sleep 5

echo "Stopping listeners"
#sudo kill ${pids[*]} >/dev/null 2>&1
sudo killall evtest
wait ${pids[*]} >/dev/null 2>&1
echo "done"

sudo rm -rf /tmp/test-fifo

echo "The mouse is $MOUSE"
echo "The keyboard is $KEYBOARD"

echo "Let's go"
./X11SimpleMultiseat.sh

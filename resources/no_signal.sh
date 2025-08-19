#!/bin/bash

# This script is responsible of the No Signal display when no video is playing.

function get_ip {
	echo $(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
}

function refresh_display {
	IP=${1}
        if [ "${IP}" == "" ]; then
                message="Please wait..."
        else
                message="rtmp://${IP}:1935/live/stream"
        fi
	/usr/bin/convert -pointsize 32 -gravity Center -fill white -draw "text 0,300 '${message}' " /opt/no_signal/no_signal.png /tmp/no_signal.png
	/usr/bin/fbi -T 2 --noverbose -d /dev/fb0 /tmp/no_signal.png
}

IP=$(get_ip)
refresh_display ${IP}
while [ "${IP}" == "" ]; do
	sleep 1
	IP=$(get_ip)
	if [ "${IP}" != "" ]; then
		refresh_display ${IP}
	fi
done

while true; do
	sleep 60
done

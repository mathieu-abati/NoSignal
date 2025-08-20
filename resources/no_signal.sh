#!/bin/bash

# This script is responsible of the No Signal display when no video is playing.

# Return an IP address, Ethernet is preferred, else Wifi
function get_ip_addr {
	local ip_addr=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
	if [ -z "${ip_addr}" ]; then
		ip_addr=$(/sbin/ip -o -4 addr list wlan0 | awk '{print $4}' | cut -d/ -f1)
	fi
	echo ${ip_addr}
}

# Refresh display with IP address
function refresh_display {
	local ip_addr=${1}
        if [[ "${ip_addr}" == "" ]]; then
                message="Please wait..."
        else
                message="rtmp://${ip_addr}:1935/live/stream"
        fi
	/usr/bin/convert -pointsize 32 -gravity Center -fill white -draw "text 0,300 '${message}' " /opt/no_signal/no_signal.png /tmp/no_signal.png
	/usr/bin/fbi -T 2 --noverbose -d /dev/fb0 /tmp/no_signal.png
}

LAST_IP_ADDR=""
while true; do
	IP_ADDR=$(get_ip_addr)
	if [ "${IP_ADDR}" != "${LAST_IP_ADDR}" ]; then
		refresh_display ${IP_ADDR}
	fi
	LAST_IP_ADDR=${IP_ADDR}
	sleep 1
done

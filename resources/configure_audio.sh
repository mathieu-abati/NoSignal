#!/bin/bash

MAX_RETRIES=4
RETRY_DELAY=2

for i in $(seq 1 $MAX_RETRIES); do
	HDMI_DEVICE=$(aplay -l | grep -i hdmi | head -1 | awk '{print $2}' | cut -d ':' -f 1)
	if [ -z "$HDMI_DEVICE" ]; then
		HDMI_DEVICE=$(cat /proc/asound/cards | grep -i hdmi | head -1 | awk '{print $1}')
	fi
	if [ -n "$HDMI_DEVICE" ]; then
		echo "defaults.pcm.card $HDMI_DEVICE" > /etc/asound.conf
		echo "defaults.ctl.card $HDMI_DEVICE" >> /etc/asound.conf
		echo "HDMI audio device (card $HDMI_DEVICE) set as default"
		/usr/bin/amixer cset numid=3 2
		exit 0
	fi
	echo "Attempt $i: No HDMI audio device found, retrying in $RETRY_DELAY seconds..."
	sleep $RETRY_DELAY
done

echo "Failed to detect HDMI audio device after $MAX_RETRIES attempts"
exit 1

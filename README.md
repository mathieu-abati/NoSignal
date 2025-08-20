# NoSignal - A media player solution to stream content from a device on your TV using a RaspberryPi

![Logo](logo.png)

This media player for RaspberryPi receives its streams through RTMP protocol,
and directly plays media on HDMI output.

It has been tested with the following boards:

| Board                  | Tested | Working | Notes                                   |
| ---------------------- | ------ | ------- | --------------------------------------- |
| RaspberryPi 1 Model B  | ✅     | ❌      | Laggy even with low-res media, no audio |
| RaspberryPi 3 Model B  | ✅     | ✅      | Perfectly working                       |
| RaspberryPi 3 Model B+ | ✅     | ✅      | Perfectly working                       |
| RaspberryPi 4 2GB      | ✅     | ✅      | Perfectly working                       |

but it is probably working with other variants (to be tested).

## Usage

Download the image from the releases page.

To flash it, you can use [RaspberryPi Imager](https://www.raspberrypi.com/software/),
and provide the NoSignal image by selecting a custom OS image.

[RaspberryPi Imager](https://www.raspberrypi.com/software/) allows you to
customize the system, for example to create your user, enable SSH access,
and configure Wifi.

Then, the first boot time, there is an automatic configuration step, which may
take a while, and if not previously done from
[RaspberryPi Imager](https://www.raspberrypi.com/software/), you will be asked
to configure keyboard layout and to create your user account.

Once booted, the streamming URI to use is written on the HDMI display, under
the "No Signal" logo. The IP address shown there is the Ethernet address in
priority, else the Wifi address.

### Share PC screen with OBS Studio

**Note:** on ArchLinux, the OBS Studio version available with `pacman` seems
not to be built with `RTMP` protocol. You can install it with `flatpak` (see
how to on official website of OBS studio).

Start [OBS Studio](https://obsproject.com), and go to `Settings`.

Switch to `Video` tab and select these options:

- Common FPS Values: 25 PAL
- Downscale folder: Bilinear
- Output (Scale) Resolution: 1280x720 or 1920x1080

Click `Apply`.

Switch to `Output` tab and select these options:

- Output Mode: Advanced
- Audio Encoder: FFmpeg Opus
- Video Encoder: x264
- Rate Control: CBR
- Bitrate: 2500
- Keyframe Interval: 1s
- CPU Usage Preset: veryfast
- Profile: main

Click `Apply`.

Switch to `Stream` tab and select these options:

- Server: `rtmp://<no_signal_ip_address>:1935/live` (replace
  `<no_signal_ip_address>` with the IP address displayed on NoSignal HDMI
  output)
- Stream Key: stream

Click `OK`.

From the main screen, in the `Sources` area add a `Screen Capture` source.

You can now click on `Start streaming`.

### Play video with ffmpeg

Replace below `<my_video_file>` and `<no_signal_ip_address>`:

```
fmpeg -re -i <my_video_file> -c:v libx264 -preset ultrafast -tune zerolatency -g 24 -c:a aac -ar 44100 -b:a 128k -f flv rtmp://<no_signal_ip_address>:1935/live/stream
```

## Build image

Follow this section if you want to build your own NoSignal image.

### Install dependencies

On Debian / Ubuntu:

```
sudo apt-get install qemu-user-static binfmt-support systemd-container
sudo systemctl enable --now systemd-binfmt
```

On ArchLinux:

```
sudo pacman -Syu qemu-user-static qemu-user-static-binfmt
```

### Build image

Just run:

```
./build_image.sh
```

The resulting image will go to current folder as `nosignal.img.xz`.
To flash it on an SD card, you can do:

```
xzcat nosignal.img.xz | sudo dd of=/dev/sdX bs=4M status=progress
sync
```

(replace `/dev/sdX` with your SD card device).

### Build uncompressed image

If you want an uncompressed image instead, run:

```
./build_image.sh --disable-compression
```

The resulting image will go to current folder as `nosignal.img`.
To flash it on an SD card, you can do:

```
sudo dd if=nosignal.img of=/dev/sdX bs=4M status=progress
sync
```

(replace `/dev/sdX` with your SD card device).

### Debugging

You can gain shell access by pressing `Enter`, or through SSH if enabled.

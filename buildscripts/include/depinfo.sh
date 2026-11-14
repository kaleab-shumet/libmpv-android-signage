#!/bin/bash -e

## Dependency versions

v_platform=android-36
v_sdk=14742923_latest
v_ndk=30.0.16248370
v_sdk_build_tools=36.0.0
v_cmake=4.1.2

v_lua=5.2.4
v_libunibreak=8_0
v_libass=0.17.5
v_harfbuzz=15.1.0
v_fribidi=1.0.18
v_freetype=2-15-0
v_libxml2=2.15.4
v_fontconfig=2.18.3
v_mbedtls=3.6.7
v_libplacebo=7.387.0
v_dav1d=1.5.4
v_ffmpeg=9.0.2
v_curl=8.23.0
v_mpv=0.42.0


## Dependency tree
# I would've used a dict but putting arrays in a dict is not a thing

dep_mbedtls=()
dep_curl=(mbedtls)
dep_dav1d=()
dep_ffmpeg=(mbedtls dav1d libxml2)
dep_freetype2=()
dep_fontconfig=(libxml2 freetype)
dep_fribidi=()
dep_harfbuzz=()
dep_libunibreak=()
dep_libass=(freetype fontconfig fribidi harfbuzz libunibreak)
dep_lua=()
dep_libplacebo=()
# lua (OSC/stats/ytdl scripts) and curl (mpv's own HTTP backend) are not needed
# for signage playback. FFmpeg's built-in HTTP(S) over mbedtls handles network
# sources instead. To bring them back: add `lua curl` here and flip
# -Dlua / -Dlibcurl to `enabled` in scripts/mpv.sh.
dep_mpv=(ffmpeg libass libplacebo)
dep_mpv_android=(mpv)

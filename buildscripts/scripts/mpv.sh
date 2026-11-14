#!/bin/bash -e

. ../../include/depinfo.sh
. ../../include/path.sh

build=_build$ndk_suffix

if [ "$1" == "build" ]; then
	true
elif [ "$1" == "clean" ]; then
	rm -rf $build
	exit 0
else
	exit 255
fi

unset CC CXX # meson wants these unset

# Signage build: no Lua (OSC, stats, ytdl hook), no libcurl backend (FFmpeg's
# http/tls is used), no libavdevice (not built, see ffmpeg.sh), size-optimised.
meson setup $build --cross-file "$prefix_dir"/crossfile.txt \
	--default-library shared \
	-Doptimization=s \
	-Diconv=disabled -D{lua,libcurl,libavdevice}=disabled \
	-Dlibmpv=true -Dcplayer=false -Dbuild-date=false \
	-Dmanpage-build=disabled

ninja -C $build -j$cores
DESTDIR="$prefix_dir" ninja -C $build install

ln -sf "$prefix_dir"/lib/libmpv.so "$native_dir"

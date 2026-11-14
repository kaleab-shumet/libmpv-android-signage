#!/bin/bash -e

. ../../include/depinfo.sh
. ../../include/path.sh

if [ "$1" == "build" ]; then
	true
elif [ "$1" == "clean" ]; then
	rm -rf _build$ndk_suffix
	exit 0
else
	exit 255
fi

mkdir -p _build$ndk_suffix
cd _build$ndk_suffix

cpu=armv7-a
[[ "$ndk_triple" == "aarch64"* ]] && cpu=armv8-a
[[ "$ndk_triple" == "x86_64"* ]] && cpu=generic
[[ "$ndk_triple" == "i686"* ]] && cpu="i686 --disable-asm"

cpuflags=
[[ "$ndk_triple" == "arm"* ]] && cpuflags="$cpuflags -mfpu=neon -mcpu=cortex-a8"

# --- Digital signage component whitelist -------------------------------------
# Everything is disabled first and only what a signage player needs is enabled.
# This is by far the largest size saving: libavcodec/libavformat otherwise carry
# ~200 decoders and ~120 demuxers.
#
# Playing something that isn't listed here fails with "Unsupported codec" or
# "Failed to recognize file format" in the mpv log. Add the missing name either
# below or, without editing this file, via FFMPEG_EXTRA_CONFIGURE, e.g.
#   FFMPEG_EXTRA_CONFIGURE="--enable-decoder=wmv3 --enable-demuxer=asf" ./build.sh
#
# Hardware video decoding goes through the *_mediacodec decoders (zero-copy with
# mpv's hwdec=mediacodec). The software decoders are the fallback for devices
# whose MediaCodec lacks a codec/profile.
decoders=(
	# video: MediaCodec (hardware)
	h264_mediacodec hevc_mediacodec vp8_mediacodec vp9_mediacodec
	av1_mediacodec mpeg2_mediacodec mpeg4_mediacodec
	# video: software fallback
	h264 hevc vp8 vp9 libdav1d mpeg1video mpeg2video mpeg4
	# still images / slides
	mjpeg png gif webp bmp
	rawvideo
	# audio
	aac aac_latm ac3 eac3 mp1 mp1float mp2 mp2float mp3 mp3float
	opus vorbis flac
	pcm_s16le pcm_s16be pcm_s24le pcm_s32le pcm_f32le pcm_u8 pcm_alaw pcm_mulaw
)
demuxers=(
	# files
	mov matroska avi flv ogg wav mp3 aac ac3 eac3 flac mpegvideo h264 hevc m4v
	# broadcast / IPTV / playlists
	mpegts mpegps hls dash concat
	# live streams (IP cameras, RTSP/RTP feeds)
	rtsp rtp sdp
	# still images
	image2 image_jpeg_pipe image_png_pipe image_gif_pipe image_webp_pipe
	image_bmp_pipe gif
)
parsers=(
	h264 hevc vp8 vp9 av1 mpeg4video mpegvideo mpegaudio aac aac_latm ac3
	opus vorbis flac mjpeg png gif webp bmp
)
# tcp/tls/http(s) for CMS downloads and HLS, udp/rtp for multicast and RTSP,
# crypto for AES-128 HLS, file for local HLS/concat playlists.
protocols=(file http https tcp tls udp rtp crypto data)

component_flags=()
for c in "${decoders[@]}";  do component_flags+=(--enable-decoder=$c);  done
for c in "${demuxers[@]}";  do component_flags+=(--enable-demuxer=$c);  done
for c in "${parsers[@]}";   do component_flags+=(--enable-parser=$c);   done
for c in "${protocols[@]}"; do component_flags+=(--enable-protocol=$c); done
# Bitstream filters the decoders/demuxers need (h264_mp4toannexb for MediaCodec,
# ...) are pulled in automatically by configure's dependency resolution.

# --disable-everything must come before the --enable-* component flags.
# libpostproc no longer exists (removed in FFmpeg 8); libavdevice is not needed.
# --enable-small builds with -Os; software decoding is a bit slower, hardware
# decoding is unaffected.
../configure \
	--target-os=android --enable-cross-compile --cross-prefix=$ndk_triple- --cc=$CC \
	--arch=${ndk_triple%%-*} --cpu=$cpu --pkg-config=pkg-config --nm=llvm-nm \
	--extra-cflags="-I$prefix_dir/include $cpuflags" --extra-ldflags="-L$prefix_dir/lib" \
	--enable-{jni,mediacodec,mbedtls,libdav1d,libxml2} --disable-vulkan \
	--disable-static --enable-shared --enable-{gpl,version3} \
	--disable-{stripping,doc,programs} \
	--disable-everything \
	--disable-{muxers,encoders,devices,filters,avdevice} \
	--disable-v4l2-m2m \
	--enable-small \
	"${component_flags[@]}" \
	$FFMPEG_EXTRA_CONFIGURE

make -j$cores
make DESTDIR="$prefix_dir" install

ln -sf "$prefix_dir"/lib/libswresample.so "$native_dir"
ln -sf "$prefix_dir"/lib/libavutil.so "$native_dir"
ln -sf "$prefix_dir"/lib/libavcodec.so "$native_dir"
ln -sf "$prefix_dir"/lib/libavformat.so "$native_dir"
ln -sf "$prefix_dir"/lib/libswscale.so "$native_dir"
ln -sf "$prefix_dir"/lib/libavfilter.so "$native_dir"

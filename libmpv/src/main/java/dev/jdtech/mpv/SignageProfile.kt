package dev.jdtech.mpv

/**
 * Option preset for unattended digital signage playback: hardware decoding,
 * looping playlists with gapless prefetch, still-image slides, no UI/input,
 * bounded memory and resilience against flaky networks and missing audio sinks.
 *
 * Apply it after [MPVLib.create] and before [MPVLib.init]:
 *
 * ```
 * val mpv = MPVLib.create(context)!!
 * val failed = SignageProfile.apply(mpv, imageSeconds = 15.0)
 * mpv.init()
 * mpv.attachSurface(surface)
 * mpv.command(arrayOf("loadfile", url))
 * ```
 *
 * Every option is applied independently, so one that is unavailable in this
 * build does not prevent the others from being set.
 */
object SignageProfile {

    /**
     * @param hardwareDecoding try MediaCodec (zero-copy, then copy mode) before
     * falling back to software decoding. Disable only to debug a device whose
     * MediaCodec misbehaves.
     * @param imageSeconds how long each still image (jpg/png/webp/...) stays on screen.
     * @param loopPlaylist restart the playlist when it ends. A single file is
     * looped too.
     * @param demuxerCacheMiB forward demuxer cache per instance. Keep small on
     * 1 GB players; 16 is enough for most 1080p streams.
     * @param demuxerBackCacheMiB cache kept behind the playback position (for seeks).
     * @return names of options mpv rejected, empty if everything was applied.
     */
    @JvmStatic
    @JvmOverloads
    fun apply(
        mpv: MPVLib,
        hardwareDecoding: Boolean = true,
        imageSeconds: Double = 10.0,
        loopPlaylist: Boolean = true,
        demuxerCacheMiB: Int = 32,
        demuxerBackCacheMiB: Int = 8,
    ): List<String> {
        val options = options(
            hardwareDecoding,
            imageSeconds,
            loopPlaylist,
            demuxerCacheMiB,
            demuxerBackCacheMiB,
        )

        val failed = mutableListOf<String>()
        for ((name, value) in options) {
            if (mpv.setOptionString(name, value) < 0) failed += name
        }
        return failed
    }

    internal fun options(
        hardwareDecoding: Boolean,
        imageSeconds: Double,
        loopPlaylist: Boolean,
        demuxerCacheMiB: Int,
        demuxerBackCacheMiB: Int,
    ): List<Pair<String, String>> {
        require(imageSeconds.isFinite() && imageSeconds > 0.0) {
            "imageSeconds must be finite and greater than zero"
        }
        require(demuxerCacheMiB >= 0) { "demuxerCacheMiB must not be negative" }
        require(demuxerBackCacheMiB >= 0) { "demuxerBackCacheMiB must not be negative" }

        return listOf(
            // No terminal, config files, key bindings or on-screen display
            "terminal" to "no",
            "config" to "no",
            "input-default-bindings" to "no",
            "input-vo-keyboard" to "no",
            "osd-level" to "0",
            "load-scripts" to "no",

            // Stay alive between items so the app can feed new content
            "idle" to "yes",
            "keep-open" to "yes",

            // Seamless transitions and endless playback
            "prefetch-playlist" to "yes",
            "gapless-audio" to "yes",
            "image-display-duration" to imageSeconds.toString(),
            // Unlike "inf", "force" retries entries marked as failed. This is
            // important when a remote item was temporarily unavailable.
            "loop-playlist" to if (loopPlaylist) "force" else "no",

            // Rendering and audio output
            "vo" to "gpu",
            "gpu-context" to "android",
            "hwdec" to if (hardwareDecoding) "mediacodec,mediacodec-copy" else "no",
            "ao" to "audiotrack,opensles",
            // Many signage players have no usable audio sink; keep showing video
            "audio-fallback-to-null" to "yes",
            "audio-display" to "no",
            "sub-auto" to "no",

            // Bounded memory for 24/7 operation
            "demuxer-max-bytes" to "${demuxerCacheMiB}MiB",
            "demuxer-max-back-bytes" to "${demuxerBackCacheMiB}MiB",

            // HTTP resilience (FFmpeg's HTTP stack is used, not libcurl).
            // Do not set mpv's network-timeout globally: mpv 0.42 documents
            // that doing so breaks RTSP client playback.
            "stream-lavf-o" to
                "reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,reconnect_delay_max=5",
        )
    }
}

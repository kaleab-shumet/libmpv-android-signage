package dev.jdtech.mpv

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Test

class SignageProfileTest {
    private fun defaultOptions(): Map<String, String> = SignageProfile.options(
        hardwareDecoding = true,
        imageSeconds = 10.0,
        loopPlaylist = true,
        demuxerCacheMiB = 32,
        demuxerBackCacheMiB = 8,
    ).toMap()

    @Test
    fun `default profile retries failed playlist entries`() {
        assertEquals("force", defaultOptions()["loop-playlist"])
    }

    @Test
    fun `default profile does not apply RTSP-breaking global timeout`() {
        assertFalse(defaultOptions().containsKey("network-timeout"))
    }

    @Test
    fun `profile rejects invalid resource limits`() {
        assertThrows(IllegalArgumentException::class.java) {
            SignageProfile.options(true, 0.0, true, 32, 8)
        }
        assertThrows(IllegalArgumentException::class.java) {
            SignageProfile.options(true, 10.0, true, -1, 8)
        }
        assertThrows(IllegalArgumentException::class.java) {
            SignageProfile.options(true, 10.0, true, 32, -1)
        }
    }
}

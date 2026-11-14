# libmpv for Android

Based on [mpv-android](https://github.com/mpv-android/mpv-android)

## Digital signage build

This fork is tuned for unattended signage players: smaller native libraries and a
runtime preset for 24/7 playback.

**What is different from upstream**

| Area | Change | How to undo / tune |
| --- | --- | --- |
| ABIs | Builds and packages `arm64-v8a` and `armeabi-v7a` only | `LIBMPV_ARCHS="armv7l arm64 x86_64" ./build.sh` and `-Plibmpv.abis=arm64-v8a,armeabi-v7a,x86_64` (Gradle) |
| FFmpeg | `--disable-everything` plus a whitelist of decoders, demuxers, parsers and protocols, `--enable-small`, no libavdevice | Edit the arrays in `buildscripts/scripts/ffmpeg.sh`, or pass `FFMPEG_EXTRA_CONFIGURE="--enable-decoder=wmv3 --enable-demuxer=asf"` |
| mpv | Lua, libcurl backend and libavdevice disabled, `-Os`, no build date | `buildscripts/scripts/mpv.sh`, `dep_mpv` in `buildscripts/include/depinfo.sh` |
| Logging | Default log level is `warn` instead of `v` | `MPVLib.requestLogMessages("v")` |
| Runtime | `SignageProfile.apply(mpv)` sets hardware decoding, looping playlist with gapless prefetch, image slide duration, bounded cache, network reconnects, audio fallback | Call it between `MPVLib.create()` and `MPVLib.init()`; every parameter is optional |

Because there is no Lua, the on-screen controller, `stats` overlay and yt-dlp hook
are not available. The libass/fontconfig text stack is unchanged (mpv 0.42 requires libass), so subtitle
and OSD text rendering behaves as upstream.

When a file will not play, check the mpv log (`adb logcat -s mpv`) for
`Unsupported codec` or `Failed to recognize file format`, then add the missing
component to the whitelist.

For unattended recovery, implement `MPVLib.EndFileObserver`. Its
`eventEndFile(reason, error)` callback distinguishes normal EOF, explicit stop,
redirect and playback errors. Existing `EventObserver` implementations remain
compatible and continue to receive `MPV_EVENT_END_FILE` without details.

`destroy()` is safe to call from an observer callback. The native instance is
then released after the event callback returns. As with other Android media
players, serialize lifecycle calls in the host application and do not issue new
commands after destruction begins.

To shrink the final APK further in your app: use ABI splits or an App Bundle, and set
`packaging { jniLibs { useLegacyPackaging = true } }` in the app module so the `.so`
files are compressed inside the APK (smaller APK, slightly larger install).

## Building from source

For a complete local build, run:

```shell
./build-signage.sh
```

Use `./build-signage.sh --arch arm64` for an arm64-only AAR, or
`./build-signage.sh --help` for all options. The first build downloads the
Android SDK/NDK and native dependency sources.

### GitHub releases

Pushing a version tag creates a GitHub release containing two AAR variants,
SHA-256 checksums and build/dependency information:

- `*-arm.aar`: `armeabi-v7a` and `arm64-v8a` for signage hardware.
- `*-universal.aar`: both ARM ABIs plus `x86` and `x86_64` for AVDs and Intel
  Android devices.

```shell
git tag v1.0.0
git push origin v1.0.0
```

Tags containing a hyphen, such as `v1.1.0-beta.1`, are published as GitHub
prereleases. The workflow uses the repository `GITHUB_TOKEN` and does not need
Maven Central credentials.

Take a look at [README.md](buildscripts/README.md) inside the `buildscripts` directory.

The AAR bundles the following native libraries, which are built by the [buildscripts](buildscripts/README.md):

| Library | Version | License |
| ------- | ------- | ------- |
| mpv | 0.42.0 | GPL-2.0-or-later |
| FFmpeg | 9.0.2 | GPL-3.0-or-later |
| libplacebo | 7.387.0 | LGPL-2.1-or-later |
| libass | 0.17.5 | ISC |
| lua | 5.2.4 | MIT |
| curl | 8.23.0 | curl license (MIT-like) |
| mbedtls | 3.6.7 | Apache-2.0 |
| freetype | 2.15.0 | FreeType License (FTL) or GPL-2.0-or-later |
| fontconfig | 2.18.3 | fontconfig license (permissive) |
| fribidi | 1.0.18 | LGPL-2.1-or-later |
| harfbuzz | 15.1.0 | Old MIT |
| libunibreak | 8.0 | Zlib |
| dav1d | 1.5.4 | BSD-2-Clause |
| libxml2 | 2.15.4 | MIT |

`libmpv.so` and the FFmpeg libraries are bundled as shared libraries, the remaining libraries are statically linked into them. Versions are maintained in [`buildscripts/include/depinfo.sh`](buildscripts/include/depinfo.sh).

## Licensing

The source code in this repository is licensed under the [MIT license](LICENSE).

Since `libmpv.so` links against the FFmpeg libraries and other GPL-licensed components, the effective license of the binaries in the AAR is **GPL-3.0-or-later**. Apps distributing the AAR must comply with the terms of that license. See the table above for the licenses of the individual components.

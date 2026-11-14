#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/buildscripts"
ARCHS="armv7l arm64"
ABIS="armeabi-v7a,arm64-v8a"
CLEAN=0
SKIP_DOWNLOAD=0
JOBS=""

usage() {
    cat <<'EOF'
Build the digital-signage libmpv AAR from source.

Usage: ./build-signage.sh [options]

Options:
  --arch arm64       Build only arm64-v8a (recommended for modern devices)
  --arch armv7l      Build only armeabi-v7a
  --arch arm         Build both ARM ABIs (default)
  --arch all         Build ARM plus x86/x86_64
  --jobs N           Number of parallel compiler jobs
  --clean            Rebuild native components from clean build directories
  --skip-download    Reuse an already downloaded SDK and dependency sources
  -h, --help         Show this help

The first run downloads the Android SDK/NDK and native sources and can take a
long time. Subsequent builds reuse those downloads.
EOF
}

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

while (($#)); do
    case "$1" in
        --arch)
            (($# >= 2)) || fail "--arch requires a value"
            case "$2" in
                arm64)
                    ARCHS="arm64"
                    ABIS="arm64-v8a"
                    ;;
                armv7l|armv7)
                    ARCHS="armv7l"
                    ABIS="armeabi-v7a"
                    ;;
                arm)
                    ARCHS="armv7l arm64"
                    ABIS="armeabi-v7a,arm64-v8a"
                    ;;
                all)
                    ARCHS="armv7l arm64 x86 x86_64"
                    ABIS="armeabi-v7a,arm64-v8a,x86,x86_64"
                    ;;
                *) fail "unsupported architecture '$2'" ;;
            esac
            shift 2
            ;;
        --jobs)
            (($# >= 2)) || fail "--jobs requires a value"
            [[ "$2" =~ ^[1-9][0-9]*$ ]] || fail "--jobs must be a positive integer"
            JOBS="$2"
            shift 2
            ;;
        --clean)
            CLEAN=1
            shift
            ;;
        --skip-download)
            SKIP_DOWNLOAD=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "unknown option '$1' (use --help)"
            ;;
    esac
done

install_prerequisites() {
    if command -v apt-get >/dev/null 2>&1; then
        printf 'Installing missing build prerequisites with apt...\n'
        if ! sudo apt-get update; then
            printf '%s\n' \
                'Warning: apt update failed because one or more configured repositories are broken.' \
                'Trying the existing package indexes; the required tools are standard Ubuntu packages.' >&2
        fi
        sudo apt-get install -y \
            autoconf automake git gperf libtool make meson nasm ninja-build \
            openjdk-17-jdk pkg-config python3 python3-jinja2 unzip wget
    elif command -v dnf >/dev/null 2>&1; then
        printf 'Installing missing build prerequisites with dnf...\n'
        sudo dnf install -y \
            autoconf automake gcc gcc-c++ git gperf java-17-openjdk-devel \
            libtool make meson nasm ninja-build pkgconf-pkg-config \
            python3 python3-jinja2 unzip wget
    elif command -v brew >/dev/null 2>&1; then
        printf 'Installing missing build prerequisites with Homebrew...\n'
        brew install autoconf automake git gperf libtool meson nasm ninja \
            openjdk@17 pkg-config python wget
    else
        fail "missing build tools and no supported package manager was found"
    fi
}

required_commands=(
    autoconf automake git gperf javac libtoolize make meson nasm ninja
    pkg-config python3 unzip wget
)

# macOS/Homebrew calls GNU libtoolize glibtoolize.
if [[ "$(uname -s)" == "Darwin" ]]; then
    required_commands=(
        autoconf automake git gperf javac glibtoolize make meson nasm ninja
        pkg-config python3 unzip wget
    )
fi

missing=()
for command_name in "${required_commands[@]}"; do
    command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
done

if ((${#missing[@]})); then
    printf 'Missing tools: %s\n' "${missing[*]}"
    install_prerequisites
fi

missing=()
for command_name in "${required_commands[@]}"; do
    command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
done
((${#missing[@]} == 0)) || fail "tools are still missing: ${missing[*]}"

java_version="$(javac -version 2>&1 | awk '{print $2}')"
java_major="${java_version%%.*}"
[[ "$java_major" =~ ^[0-9]+$ ]] || fail "could not determine the Java version"
((java_major >= 17)) || fail "JDK 17 or newer is required (found $java_version)"

available_kib="$(df -Pk "$PROJECT_DIR" | awk 'NR == 2 {print $4}')"
if [[ "$available_kib" =~ ^[0-9]+$ ]] && ((available_kib < 10 * 1024 * 1024)); then
    printf 'Warning: less than 10 GiB is free; a full native build may run out of space.\n' >&2
fi

printf '\nConfiguration\n'
printf '  Project: %s\n' "$PROJECT_DIR"
printf '  Native architectures: %s\n' "$ARCHS"
printf '  Packaged ABIs: %s\n' "$ABIS"
printf '  Clean build: %s\n\n' "$([[ "$CLEAN" == 1 ]] && printf yes || printf no)"

cd "$BUILD_DIR"

if [[ "$SKIP_DOWNLOAD" == 0 ]]; then
    printf 'Downloading/checking Android SDK and native dependencies...\n'
    # The wrapper manages host packages itself. IN_CI=1 tells the existing
    # downloader to skip its sudo/pip installation branch only.
    IN_CI=1 ./download.sh
else
    [[ -d sdk && -d deps ]] || fail "--skip-download was used but buildscripts/sdk or buildscripts/deps is missing"
fi

printf '\nApplying dependency patches...\n'
./patch.sh

build_args=()
if [[ "$CLEAN" == 1 ]]; then
    build_args+=(--clean)
fi

printf '\nBuilding libmpv and the release AAR...\n'
export LIBMPV_ARCHS="$ARCHS"
export LIBMPV_ABIS="$ABIS"
if [[ -n "$JOBS" ]]; then
    export cores="$JOBS"
fi
./build.sh "${build_args[@]}"

aar="$PROJECT_DIR/libmpv/build/outputs/aar/libmpv-release.aar"
[[ -f "$aar" ]] || fail "the build finished without producing $aar"

printf '\nBuild complete.\n'
ls -lh "$aar"
printf '\nAAR: %s\n' "$aar"

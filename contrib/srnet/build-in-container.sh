#!/usr/bin/env bash
# Build session-router + session-router-config from this checkout inside ubuntu:24.04.
#   podman run --rm -v "$PWD":/src:ro -v "$PWD/out":/out docker.io/library/ubuntu:24.04 \
#       bash /src/contrib/srnet/build-in-container.sh
# The checkout must be committed: the build uses a clean clone of HEAD, not the working tree.
set -euo pipefail
OUT=/out; WORK=/build; JOBS=${JOBS:-$(nproc)}
UPSTREAM_BASE=afb98f959f4f7e0ef996aef02fa21a6caf26b1e9
SUBMODULES="cmake/session-deps external/CLI11 external/mlkem-native external/nlohmann external/oxen-libquic external/oxen-mq external/sqlite_orm external/pybind11"
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get install -y -q --no-install-recommends build-essential g++ cmake ninja-build git pkg-config automake autoconf libtool \
  python3 python3-dev curl ca-certificates patch xz-utils file \
  libsodium-dev libzmq3-dev libcurl4-openssl-dev libevent-dev nettle-dev libunbound-dev libssl-dev nlohmann-json3-dev \
  libsqlite3-dev libsystemd-dev libgnutls28-dev libzstd-dev libfmt-dev libspdlog-dev libcli11-dev libcap-dev libuv1-dev dpkg-dev
git config --global --add safe.directory '*'
SRC=$WORK/session-router; BUILD=$WORK/b; mkdir -p "$OUT"
# INCREMENTAL=1 (with a persistent /build) reuses the previous clone and build tree.
if [ "${INCREMENTAL:-0}" = 1 ] && [ -d "$SRC/.git" ]; then
  git -C "$SRC" fetch -q /src HEAD && git -C "$SRC" checkout -q -f FETCH_HEAD
else
  rm -rf "$SRC" "$BUILD"; git clone -q /src "$SRC"
fi
COMMIT=$(git -C "$SRC" rev-parse HEAD)
git -C "$SRC" merge-base --is-ancestor "$UPSTREAM_BASE" "$COMMIT" || { echo "HEAD is not based on upstream $UPSTREAM_BASE"; exit 1; }
git -C "$SRC" submodule update -q --init --recursive --depth 1 --jobs 4 -- $SUBMODULES
# Ubuntu 24.04's ngtcp2 is too old for libquic, which then builds a static ngtcp2 that has to find
# the system gnutls (backport of session-deps d74f5b1376).
for f in $(find "$SRC" -path '*/session-deps/deps/libngtcp2.cmake' -not -path '*/.git/*'); do
  d=$(dirname "$(dirname "$f")")
  git -C "$d" apply --reverse --check "$SRC/contrib/srnet/session-deps/0001-libngtcp2-find-system-gnutls.patch" 2>/dev/null \
    || git -C "$d" apply "$SRC/contrib/srnet/session-deps/0001-libngtcp2-find-system-gnutls.patch"
done
git -C "$SRC" submodule status -- $SUBMODULES > "$OUT/SUBMODULES"
export SOURCE_DATE_EPOCH=$(git -C "$SRC" log -1 --format=%ct)
export CFLAGS="-ffile-prefix-map=$WORK=/build" CXXFLAGS="-ffile-prefix-map=$WORK=/build"
# WITH_SYSTEMD=ON: the stock session-router-client unit is Type=notify + WatchdogSec=30s.
cmake -S "$SRC" -B "$BUILD" -G Ninja -DCMAKE_BUILD_TYPE=Release -DSROUTER_NATIVE_BUILD=OFF -DSROUTER_JEMALLOC=OFF \
  -DBUILD_SHARED_LIBS=OFF -DSUBMODULE_CHECK=OFF -DWITH_SYSTEMD=ON -DSROUTER_WARNINGS_AS_ERRORS=OFF \
  -DBUILD_STATIC_DEPS=OFF -DSTATIC_LINK=OFF > "$OUT/configure.log" 2>&1 || { tail -60 "$OUT/configure.log"; exit 1; }
cmake --build "$BUILD" --target session-router session-router-config -j "$JOBS"
for t in session-router session-router-config; do
  b=$(find "$BUILD" -maxdepth 3 -type f -name "$t" -perm -u+x | head -1); strip --strip-all -o "$OUT/$t" "$b"
done
mkdir -p /tmp/shl/debian && cd /tmp/shl && printf 'Source: x\n\nPackage: x\nArchitecture: amd64\n' > debian/control
dpkg-shlibdeps -O "$OUT/session-router" "$OUT/session-router-config" > "$OUT/shlibs.substvars" 2>"$OUT/shlibdeps.err"
cp "$SRC/LICENSE" "$OUT/LICENSE"
{ echo "source_commit=$COMMIT"
  echo "upstream_base=$UPSTREAM_BASE"
  echo "with_systemd=yes static_deps=no"
  echo "os=$(. /etc/os-release; echo "$ID $VERSION_ID")"; echo "compiler=$(g++ --version | head -1)"
  echo "source_date_epoch=$SOURCE_DATE_EPOCH"
  echo "sha256_session-router=$(sha256sum "$OUT/session-router" | cut -d' ' -f1)"
  echo "sha256_session-router-config=$(sha256sum "$OUT/session-router-config" | cut -d' ' -f1)"; } > "$OUT/BUILDINFO"
cat "$OUT/BUILDINFO"; echo BUILD_OK

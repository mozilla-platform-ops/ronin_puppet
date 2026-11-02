#!/bin/bash

# Builds a universal (arm64 + x86_64) duo_unix pkg for duo::duo_unix
# (install_method => 'pkg').
#
# OpenSSL is linked statically, so the payload is just pam_duo.so and nothing
# lands on the compiler/linker search paths of the build workers.
#
# Usage: tools/build_duo_unix_pkg.sh [output_dir]
# Upload the result to
#   s3://ronin-puppet-package-repo/macos/public/common/
# and set duo::duo_unix's pkg_version and pkg_checksum to match.

set -euo pipefail

DUO_VERSION="2.3.0"
# https://duo.com/docs/checksums
DUO_SHA256="e34302bed77529d249ea3148b91563a577a8090ee575925174b4cd273adc9ea1"
OPENSSL_VERSION="3.5.9"
# https://github.com/openssl/openssl/releases/download/openssl-3.5.9/openssl-3.5.9.tar.gz.sha256
OPENSSL_SHA256="603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a"

PKG_IDENTIFIER="org.mozilla.relops.duo_unix"
export MACOSX_DEPLOYMENT_TARGET="11.0"

OUT_DIR="$(cd "${1:-.}" && pwd)"
WORK="$(mktemp -d /tmp/duo_unix_pkg.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
JOBS="$(sysctl -n hw.ncpu)"

fetch() {
    local url="$1" sha="$2" out="$3"
    curl -fsSL -o "$out" "$url"
    echo "$sha  $out" | shasum -a 256 -c -
}

cd "$WORK"
fetch "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz" \
    "$OPENSSL_SHA256" openssl.tar.gz
fetch "https://dl.duosecurity.com/duo_unix-${DUO_VERSION}.tar.gz" "$DUO_SHA256" duo_unix.tar.gz

######
# Static OpenSSL, one build per arch, then lipo
######

for arch in arm64 x86_64; do
    mkdir "src-$arch"
    tar -xzf openssl.tar.gz -C "src-$arch" --strip-components 1
    (
        cd "src-$arch"
        CC="clang" CFLAGS="-arch $arch" LDFLAGS="-arch $arch" ./Configure "darwin64-$arch-cc" \
            no-shared no-tests no-docs --prefix="$WORK/openssl-$arch" --libdir=lib
        make -j"$JOBS"
        make install_sw
    )
done

# The generated headers must match across arches for one include dir to serve both
diff -r openssl-arm64/include openssl-x86_64/include

mkdir -p openssl/lib
cp -R openssl-arm64/include openssl/
for lib in libcrypto.a libssl.a; do
    lipo -create "openssl-arm64/lib/$lib" "openssl-x86_64/lib/$lib" -output "openssl/lib/$lib"
done

######
# duo_unix, built universal in one pass
######

mkdir duo_unix
tar -xzf duo_unix.tar.gz -C duo_unix --strip-components 1
(
    cd duo_unix
    # 2.3.0's https.c calls strftime_l, which macOS only declares in <xlocale.h>
    CC="clang" CFLAGS="-arch arm64 -arch x86_64 -include xlocale.h" LDFLAGS="-arch arm64 -arch x86_64" ./configure \
        --disable-dependency-tracking \
        --with-openssl="$WORK/openssl" \
        --with-pam=/usr/local/lib/pam
    make -j"$JOBS"
    make install DESTDIR="$WORK/stage"
)

######
# Package pam_duo.so only
######

PAM_DUO="usr/local/lib/pam/pam_duo.so"
mkdir -p "root/$(dirname "$PAM_DUO")"
cp "stage/$PAM_DUO" "root/$PAM_DUO"
strip -x "root/$PAM_DUO"
chmod 0755 "root/$PAM_DUO"

for arch in arm64 x86_64; do
    if ! lipo -archs "root/$PAM_DUO" | tr ' ' '\n' | grep -qx "$arch"; then
        echo "Error: pam_duo.so is missing $arch!"
        exit 1
    fi
done
if otool -L "root/$PAM_DUO" | grep -Eq 'lib(ssl|crypto)'; then
    echo "Error: pam_duo.so is dynamically linked against OpenSSL!"
    exit 1
fi

PKG="$OUT_DIR/duo_unix-${DUO_VERSION}-universal.pkg"
pkgbuild --root root \
    --identifier "$PKG_IDENTIFIER" \
    --version "$DUO_VERSION" \
    --install-location / \
    --ownership recommended \
    "$PKG"

echo
pkgutil --payload-files "$PKG"
shasum -a 256 "$PKG"

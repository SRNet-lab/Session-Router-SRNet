#!/usr/bin/env bash
# make-deb.sh OUTDIR VERSION DESTDIR
# Package OUTDIR/{session-router,session-router-config,LICENSE,BUILDINFO,SUBMODULES,shlibs.substvars}
# (from build-in-container.sh) as session-router-srnet, a drop-in replacement for session-router-bin.
set -euo pipefail
O=$1; V=$2; DEST=$3; H=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d); R=$T/session-router-srnet
mkdir -p $R/DEBIAN $R/usr/bin $R/usr/share/doc/session-router-srnet
install -m755 $O/session-router $O/session-router-config $R/usr/bin/
D=$R/usr/share/doc/session-router-srnet
cp $O/LICENSE $D/LICENSE; cp $H/copyright $D/copyright; cp $O/BUILDINFO $O/SUBMODULES $D/
(cd $R/usr/bin && sha256sum session-router session-router-config) > $D/SHA256SUMS
install -m755 $H/postinst $R/DEBIAN/postinst
COMMIT=$(sed -n 's/^source_commit=//p' $O/BUILDINFO)
DEPS=$(sed 's/^shlibs:Depends=//' $O/shlibs.substvars); SZ=$(du -sk $R/usr | cut -f1)
cat > $R/DEBIAN/control <<C
Package: session-router-srnet
Source: session-router
Version: $V
Architecture: amd64
Maintainer: ${DEB_MAINTAINER:-SRNet <noreply@srnet.invalid>}
Installed-Size: $SZ
Depends: $DEPS, adduser, curl
Provides: session-router-bin (= 1.1.0-1~ubuntu2404)
Conflicts: session-router-bin
Replaces: session-router-bin
Section: net
Priority: optional
Homepage: https://github.com/session-foundation/session-router
Description: Session Router with client exit mapping (MapExit) -- binaries
 Drop-in replacement for session-router-bin 1.1.0, for use with the stock
 session-router-client service. Built from session-router commit
 $COMMIT
 (upstream afb98f959f4f plus the Linux route-poking fix and client exit
 mapping). Build inputs: see BUILDINFO in /usr/share/doc/session-router-srnet.
C
(cd $R && find usr -type f -exec md5sum {} \; | sort -k2 > DEBIAN/md5sums)
SOURCE_DATE_EPOCH=$(sed -n 's/^source_date_epoch=//p' $O/BUILDINFO) \
  dpkg-deb --root-owner-group -Zxz --build $R $DEST/session-router-srnet_${V}_amd64.deb >/dev/null
rm -rf $T
(cd $DEST && sha256sum session-router-srnet_${V}_amd64.deb | tee session-router-srnet_${V}_amd64.deb.sha256)

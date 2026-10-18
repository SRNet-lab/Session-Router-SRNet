# SRNet build of Session Router

The Session Router build used by the SRNet client,
[SRNet-Desktop](https://github.com/SRNet-lab/SRNet-Desktop). Install it by following the
[SRNet-Desktop install steps](https://github.com/SRNet-lab/SRNet-Desktop#install).

SRNet is an independent project. It is not affiliated with or endorsed by the Session Foundation
or the Session Technology Foundation.

This branch (`srnet/mapexit-dev`) is upstream
[session-foundation/session-router](https://github.com/session-foundation/session-router)
`afb98f959f4f7e0ef996aef02fa21a6caf26b1e9` plus:

| Branch | What |
|---|---|
| `upstream-base` | upstream `afb98f959f4f`, unmodified |
| `fix/linux-route-poking` | Linux default-gateway discovery, route install, IPv6 blackhole fixes |
| `feature/map-exit` | client exit mapping: `MapExit` / `UnmapExit` / `SwapExits` RPC and exit route poking |
| `srnet/mapexit-dev` | both of the above plus this Ubuntu 24.04 build and `.deb` packaging |

## The package

`session-router-srnet` contains `/usr/bin/session-router` and `/usr/bin/session-router-config`.
It `Provides`, `Replaces` and `Conflicts` with `session-router-bin (= 1.1.0-1~ubuntu2404)`, so it
works under the stock Session Foundation `session-router-client` service. The oxen/session libraries
are linked statically, so it needs only the Ubuntu runtime libraries listed in its `Depends`.

Install it together with the stock client package in one command (Session Foundation apt repo
already added), so the stock binary is never installed:

```sh
cd /tmp
curl -fLO https://github.com/SRNet-lab/Session-Router-SRNet/releases/download/v1.1.0-srnet6/session-router-srnet_1.1.0+srnet6_amd64.deb
sudo apt install -y ./session-router-srnet_1.1.0+srnet6_amd64.deb session-router-client
sudo apt-mark hold session-router-srnet session-router-client
```

If `session-router-bin` was installed first, installing this package removes it and apt then lists
`libsessionrouter1.1`, `liboxen-quic1.12` and friends as no longer required. That is expected:
`apt autoremove` can remove them safely, this build does not use them.

Back to stock: `sudo apt-mark unhold session-router-srnet session-router-client && sudo apt install session-router-bin`.

## Building

```sh
mkdir -p out dist
podman run --rm -v "$PWD":/src:ro -v "$PWD/out":/out docker.io/library/ubuntu:24.04 \
    bash /src/contrib/srnet/build-in-container.sh       # docker works the same way
contrib/srnet/make-deb.sh out 1.1.0+srnet6 dist          # needs dpkg-deb
```

The build uses a clean clone of the committed `HEAD`. `out/BUILDINFO` records the source commit,
compiler and the sha256 of both binaries; it is installed in `/usr/share/doc/session-router-srnet/`.

## License

GPL-3.0-or-later, the same as upstream Session Router. See [LICENSE](../../LICENSE).

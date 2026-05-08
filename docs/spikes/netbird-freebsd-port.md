# NetBird FreeBSD Port Spike

Date: 2026-05-08

## Question

Can NetBird be integrated into foji-bsd as `security/netbird`, and do we need
to fork upstream `netbirdio/netbird` to make that feasible?

## Findings

NetBird is already present in the official FreeBSD ports tree as
`security/netbird`. The official port currently builds only the client daemon
and CLI from `./client`:

```make
PORTNAME=	netbird
DISTVERSION=	0.70.0
CATEGORIES=	security net net-vpn
USES=		go:modules
USE_RC_SUBR=	${PORTNAME}
GO_MODULE=	github.com/netbirdio/netbird
GO_TARGET=	./client:${PORTNAME}
GO_BUILDFLAGS=	-tags freebsd -o ${PORTNAME} -ldflags \
		"-s -w -X github.com/netbirdio/netbird/version.version=${DISTVERSION}"
```

The official port also ships an rc.d script that runs:

```sh
netbird service run \
  --config /var/db/netbird/config.json \
  --daemon-addr unix:///var/run/netbird.sock \
  --log-file /var/log/netbird/client.log
```

Upstream itself carries FreeBSD-specific client code, including interface,
system information, DNS, route management, and version URL files. It also has a
FreeBSD GitHub Actions workflow that builds `client/main.go` and runs selected
client-side tests in a FreeBSD VM. That workflow explicitly excludes the
management server from FreeBSD support:

```text
check all component except management, since we do not support management server on freebsd
```

The upstream release configuration matches that split. The `netbird` client
release targets Linux, Darwin, and Windows in goreleaser, while management,
signal, relay, combined server, upload, proxy, and migration binaries are
Linux-only.

## Build Probe

I cloned upstream NetBird to `/tmp/netbird-spike` and tested the FreeBSD client
build path from Linux with Go 1.25.5:

```sh
GOOS=freebsd GOARCH=amd64 CGO_ENABLED=0 \
  GOCACHE=/tmp/go-build-netbird-v070 \
  GOMODCACHE=/tmp/go-mod-netbird-v070 \
  go build -tags freebsd -o /tmp/netbird-freebsd-v0.70.0 ./client
```

That cross-build failed:

```text
golang.zx2c4.com/wireguard/wgctrl: undefined: wgfreebsd.New
github.com/godbus/dbus/v5: *unixTransport does not implement transport
```

The `wgctrl` failure is expected with `CGO_ENABLED=0`: its FreeBSD kernel
WireGuard client file uses cgo. This does not prove the official FreeBSD port
is broken because poudriere builds on FreeBSD instead of Linux cross-building
with cgo disabled.

The `dbus` failure is a dependency compatibility risk worth watching, but it
should also be validated in the real FreeBSD poudriere environment before
patching. The official upstream FreeBSD CI installs Go directly in a FreeBSD VM
and builds the client there.

## Recommendation

Do not fork upstream for the first milestone.

For foji-bsd, start by importing the official FreeBSD `security/netbird` port
with minimal local changes:

- keep it client-only;
- track the current upstream release selected for our repo;
- keep `NOT_FOR_ARCHS=i386`;
- keep the rc.d service path;
- validate with poudriere on the native FreeBSD builder or local FreeBSD VM.

A fork is only justified if one of these becomes true:

- the official client port fails in our poudriere environment and cannot be
  fixed with small local port patches;
- we need NetBird management, signal, relay, or combined server binaries on
  FreeBSD;
- we need behavior changes in the daemon itself rather than packaging changes.

## Proposed First Milestone

Add `security/netbird` to foji-bsd from the official FreeBSD port, then run:

```sh
FOJI_BUILDER_ARCH=amd64 \
REQUESTED_PORTS=security/netbird \
REPO_PACKAGE_ORIGINS=security/netbird \
PUBLISH=no \
scripts/native-freebsd-build.sh build
```

If that succeeds, add a profile for sysbsd nodes that should receive NetBird.
If it fails, inspect the poudriere log before deciding between a local port
patch and an upstream fork.

## Sources

- Upstream repository: https://github.com/netbirdio/netbird
- Official FreeBSD port: https://cgit.freebsd.org/ports/tree/security/netbird
- FreeBSD Porter's Handbook, Go ports: https://docs.freebsd.org/en/books/porters-handbook/book/#uses-go

# NetBird FreeBSD Port Spike

Date: 2026-05-08

## Question

Can NetBird be integrated into foji-bsd as `security/netbird`, and do we need
to fork upstream `netbirdio/netbird` to make the client and self-hosted server
stack available on FreeBSD?

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

The upstream release configuration matches that split for official artifacts.
The `netbird` client release targets Linux, Darwin, and Windows in goreleaser,
while management, signal, relay, combined server, upload, proxy, and migration
binaries are Linux-only in the official release pipeline.

That release matrix does not mean every server component is source-incompatible
with FreeBSD. It only means upstream does not currently ship or test those
server artifacts for FreeBSD.

## Client Build Probe

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

## Server Stack Probe

I also probed the server-side components at upstream tag `v0.70.0` from Linux
with `GOOS=freebsd` and an isolated module cache.

Successful pure-Go FreeBSD cross-builds:

```sh
GOOS=freebsd GOARCH=amd64 CGO_ENABLED=0 go build -tags freebsd ./signal
GOOS=freebsd GOARCH=amd64 CGO_ENABLED=0 go build -tags freebsd ./relay
GOOS=freebsd GOARCH=amd64 CGO_ENABLED=0 go build -tags freebsd ./upload-server
```

These results are encouraging: Signal, Relay, and Upload Server do not appear
to require Linux-specific source changes for a first FreeBSD port. They still
need rc.d scripts, config files, users/directories, and runtime validation.

Components that need native FreeBSD validation:

```sh
GOOS=freebsd GOARCH=amd64 CGO_ENABLED=1 go build -tags freebsd ./management
GOOS=freebsd GOARCH=amd64 CGO_ENABLED=1 go build -tags freebsd ./combined
GOOS=freebsd GOARCH=amd64 CGO_ENABLED=1 go build -tags freebsd ./tools/idp-migrate
```

Cross-building those from Linux fails at the Go cgo runtime boundary because
the Linux host does not have FreeBSD headers:

```text
runtime/cgo: gcc_freebsd_amd64.c:7:10: fatal error: 'sys/signalvar.h' file not found
```

That is not a NetBird source failure. It means management, combined server, and
the migration helper must be built inside FreeBSD/poudriere before judging
feasibility.

Management and combined server are cgo-relevant because they pull in the
SQLite-backed Dex path through `github.com/netbirdio/dex` and
`github.com/mattn/go-sqlite3`. A no-cgo build gets further but fails because
the no-cgo Dex SQLite type does not expose the `File` field NetBird uses:

```text
idp/dex/config.go: unknown field File in struct literal of type sql.SQLite3
idp/dex/provider.go: unknown field File in struct literal of type sql.SQLite3
```

So the practical path is not "disable cgo"; it is "build management/combined
natively on FreeBSD with cgo enabled".

The proxy is different. A no-cgo FreeBSD build fails with the same client-side
FreeBSD dependency errors as the client:

```text
golang.zx2c4.com/wireguard/wgctrl: undefined: wgfreebsd.New
github.com/godbus/dbus/v5: *unixTransport does not implement transport
```

This happens because proxy code imports embedded client/status paths and shared
relay/management client code that reaches WireGuard and dbus dependencies. The
proxy may also build natively with cgo enabled, but it should be treated as a
second-stage target after client and core server components.

## Server Packaging Shape

For a FreeBSD self-hosted stack, the least risky package split is:

- `security/netbird`: existing client daemon and CLI.
- `security/netbird-signal`: Signal server, pure Go.
- `security/netbird-relay`: Relay server plus optional STUN listener, pure Go.
- `security/netbird-upload`: debug upload server, pure Go, optional.
- `security/netbird-mgmt`: management server, cgo-enabled, native FreeBSD
  build required.
- `security/netbird-server`: combined self-hosted server, cgo-enabled, native
  FreeBSD build required.
- `security/netbird-proxy`: defer until proxy's embedded client dependency
  behavior is validated natively.

The combined server is attractive operationally because it multiplexes
management, signal, relay, and optional STUN around one YAML configuration.
Its config supports a `server` block with `listenAddress`, `exposedAddress`,
`authSecret`, `dataDir`, store settings, auth settings, TLS settings, and
external overrides for STUN, relay, and signal.

For FreeBSD, rc.d integration needs to use FreeBSD paths rather than upstream
Linux defaults such as `/var/lib/netbird`:

- state/data: `/var/db/netbird` or `/var/db/netbird-server`;
- logs: `/var/log/netbird`;
- configs: `${PREFIX}/etc/netbird`;
- runtime sockets/pids: `/var/run/netbird*`.

## Recommendation

Do not fork upstream for the client, signal, relay, or upload-server first
milestones.

For foji-bsd, proceed incrementally:

1. Import the official FreeBSD client port with minimal local changes.
2. Add separate pure-Go ports for `netbird-signal` and `netbird-relay`.
3. Validate `netbird-mgmt` and `netbird-server` inside the FreeBSD builder with
   cgo enabled before creating permanent ports for them.
4. Defer `netbird-proxy` until the embedded client dependency path is proven
   natively.

A fork is only justified if one of these becomes true:

- management or combined server fails in a native FreeBSD/poudriere build for
  source-level reasons, not only cgo cross-build reasons;
- proxy requires code changes to decouple server-side proxy behavior from
  client WireGuard/dbus paths;
- we need stable FreeBSD server support faster than upstream is willing to
  carry it;
- we need behavior changes rather than packaging, rc.d, or path fixes.

If a fork becomes necessary, keep it narrow: carry FreeBSD build tags, path
defaults, and server artifact support, while continuing to track upstream
release tags.

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

Then create small first-pass ports for the pure-Go server components:

```text
security/netbird-signal  -> ./signal:netbird-signal
security/netbird-relay   -> ./relay:netbird-relay
security/netbird-upload  -> ./upload-server:netbird-upload
```

After those build, attempt native poudriere builds for:

```text
security/netbird-mgmt    -> ./management:netbird-mgmt, cgo enabled
security/netbird-server  -> ./combined:netbird-server, cgo enabled
```

Treat `security/netbird-proxy` as a follow-up spike unless a native FreeBSD
build succeeds without source changes.

## Sources

- Upstream repository: https://github.com/netbirdio/netbird
- Official FreeBSD port: https://cgit.freebsd.org/ports/tree/security/netbird
- FreeBSD Porter's Handbook, Go ports: https://docs.freebsd.org/en/books/porters-handbook/book/#uses-go

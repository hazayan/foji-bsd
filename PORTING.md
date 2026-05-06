# Porting Guidelines

## Rust Ports

Rust-based foji-bsd ports should avoid building `lang/rust` in poudriere. The
preferred mechanism depends on whether rustup supports the build host target.

On `amd64`, use the rustup-managed toolchain pattern from `sysutils/zhamel` and
the `amd64` path in `sysutils/kunci` instead of depending directly on
`lang/rust`.

Keep `USES=cargo` so the FreeBSD ports framework still handles vendored crates,
`Makefile.crates`, and cargo targets, but set `CARGO_BUILDDEP=no` and add:

```make
BUILD_DEPENDS=	rustup-init:devel/rustup-init

CARGO_BUILDDEP=	no
CARGO_CONFIGURE=	no
CARGO_INSTALL=	no
CARGO_ENV+=	RUSTUP_HOME=${RUSTUP_HOME}
RUSTUP_HOME=	${WRKDIR}/rustup-home
CARGO=		${WRKDIR}/cargo-home/bin/cargo
RUSTC=		${WRKDIR}/cargo-home/bin/rustc
RUSTDOC=	${WRKDIR}/cargo-home/bin/rustdoc
```

The port should bootstrap rustup in `do-configure`, install a pinned minimal
toolchain under `${WRKDIR}`, and then set that toolchain as default for the build.
This avoids forcing poudriere to build `lang/rust` when the upstream package
repository has not caught up with the ports tree revision.

For multi-binary workspaces, prefer `CARGO_INSTALL=no` with an explicit
`do-install` that stages already-built artifacts from `${CARGO_TARGET_DIR}`.
Build only the packages that are staged, for example with
`CARGO_BUILD_ARGS=--package name-one --package name-two --locked`. Avoid
`--workspace` unless every workspace member belongs in the port package, and
avoid multiple `CARGO_INSTALL_PATH` entries unless recompilation during the
install phase is acceptable.

Do not apply this pattern blindly on `aarch64`: the FreeBSD `devel/rustup-init`
port is currently `amd64`-only, and upstream Rust only distributes rustup host
tools for the FreeBSD x86 host targets. For native `aarch64` Rust ports, keep the
standard `USES=cargo` dependency path and align the poudriere ports tree branch
with the upstream package branch so `lang/rust` can be fetched as a binary
package. The local QEMU builder defaults aarch64 to FreeBSD's `quarterly`
package branch and the matching `2026Q2` ports branch for this reason. It also
temporarily pins `PORTS_REF` to the 2026Q2 commit before `ftp/curl` moved beyond
the currently published FreeBSD:15:aarch64 quarterly package set. If the
upstream quarterly package set catches up or drifts again, update `PORTS_REF` to
the package-compatible snapshot before starting a long build.

For native Rust binaries, pin the full host toolchain triple per architecture,
for example:

```make
RUSTUP_VERSION=	1.95.0
.if ${ARCH} == amd64
RUSTUP_HOST_TRIPLE=	x86_64-unknown-freebsd
.elif ${ARCH} == aarch64
RUSTUP_HOST_TRIPLE=	aarch64-unknown-freebsd
.endif
RUSTUP_TOOLCHAIN=	${RUSTUP_VERSION}-${RUSTUP_HOST_TRIPLE}
```

For non-native Rust targets, add the required target to the rustup install
command and configure the linker explicitly, as `sysutils/zhamel` does for
`x86_64-unknown-uefi`.

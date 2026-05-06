PORTNAME=	zhamel
DISTVERSION=	0.9.0
CATEGORIES=	sysutils
USE_GITHUB=	yes
GH_ACCOUNT=	hazayan
GH_TAGNAME=	v${DISTVERSION}

MAINTAINER=	yassine@hazayan.dev
COMMENT=	Rust UEFI loader for FreeBSD with ZFS unlock extensions
WWW=		https://github.com/hazayan/zhamel

LICENSE=	MIT
LICENSE_FILE=	${WRKSRC}/LICENSE

ONLY_FOR_ARCHS=	amd64

MASTER_SITES+=	https://static.rust-lang.org/dist/:ruststd
DISTFILES+=	${RUST_HOST_DIST}:ruststd \
		${RUST_STD_DIST}:ruststd

USES=		cargo

SUB_FILES=	pkg-message

CARGO_BUILDDEP=	no
CARGO_CONFIGURE=	no
CARGO_BUILD=	yes
CARGO_INSTALL=	no
CARGO_TEST=	no
CARGO_BUILD_ARGS=	--target x86_64-unknown-uefi --locked
CARGO_ENV+=	CARGO_TARGET_X86_64_UNKNOWN_UEFI_LINKER=${RUST_LLD}
RUSTUP_TOOLCHAIN=	1.94.0
RUST_HOST_TRIPLE=	x86_64-unknown-freebsd
RUST_STD_TARGET=	x86_64-unknown-uefi
RUST_HOST_DIST=	rust-${RUSTUP_TOOLCHAIN}-${RUST_HOST_TRIPLE}.tar.xz
RUST_HOST_WRKSRC=	${WRKDIR}/rust-${RUSTUP_TOOLCHAIN}-${RUST_HOST_TRIPLE}
RUST_STD_DIST=	rust-std-${RUSTUP_TOOLCHAIN}-${RUST_STD_TARGET}.tar.xz
RUST_STD_WRKSRC=	${WRKDIR}/rust-std-${RUSTUP_TOOLCHAIN}-${RUST_STD_TARGET}
RUST_SYSROOT=	${WRKDIR}/rust-sysroot
RUST_LLD=	${RUST_SYSROOT}/lib/rustlib/${RUST_HOST_TRIPLE}/bin/rust-lld
CC=		${RUST_LLD}
RUSTFLAGS+=	-C linker=${RUST_LLD}
CARGO=		${RUST_SYSROOT}/bin/cargo
RUSTC=		${RUST_SYSROOT}/bin/rustc
RUSTDOC=	${RUST_SYSROOT}/bin/rustdoc

PLIST_FILES=	share/efi/FreeBSD/zhamel.efi

.include "Makefile.crates"

do-configure:
	${MKDIR} ${RUST_SYSROOT}
	cd ${RUST_HOST_WRKSRC} && ${SH} install.sh \
		--prefix=${RUST_SYSROOT} \
		--disable-ldconfig
	cd ${RUST_STD_WRKSRC} && ${SH} install.sh \
		--prefix=${RUST_SYSROOT} \
		--disable-ldconfig
	${MKDIR} ${WRKSRC}/.cargo
	${PRINTF} "[source.cargo]\ndirectory = '${WRKSRC}/cargo-crates'\n[source.crates-io]\nreplace-with = 'cargo'\n" \
		> ${WRKSRC}/.cargo/config.toml

do-install:
	${MKDIR} ${STAGEDIR}${PREFIX}/share/efi/FreeBSD
	${INSTALL_DATA} ${CARGO_TARGET_DIR}/x86_64-unknown-uefi/release/zhamel.efi \
		${STAGEDIR}${PREFIX}/share/efi/FreeBSD/zhamel.efi

.include <bsd.port.mk>

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

BUILD_DEPENDS=	rustup-init:devel/rustup-init

USES=		cargo

SUB_FILES=	pkg-message

CARGO_BUILDDEP=	no
CARGO_CONFIGURE=	no
CARGO_BUILD=	yes
CARGO_INSTALL=	no
CARGO_TEST=	no
CARGO_BUILD_ARGS=	--target x86_64-unknown-uefi --locked
CARGO_ENV+=	RUSTUP_HOME=${RUSTUP_HOME}
CARGO_ENV+=	CARGO_TARGET_X86_64_UNKNOWN_UEFI_LINKER=${RUSTUP_LLD}
CARGO_ENV+=	RUSTFLAGS="-C ar=${AR}"
RUSTUP_HOME=	${WRKDIR}/rustup-home
RUSTUP_HOST_TRIPLE=	x86_64-unknown-freebsd
RUSTUP_TOOLCHAIN=	1.94.0
RUSTUP_LLD=	${RUSTUP_HOME}/toolchains/${RUSTUP_TOOLCHAIN}-${RUSTUP_HOST_TRIPLE}/lib/rustlib/${RUSTUP_HOST_TRIPLE}/bin/rust-lld
CC=		${RUSTUP_LLD}
CARGO=		${WRKDIR}/cargo-home/bin/cargo
RUSTC=		${WRKDIR}/cargo-home/bin/rustc
RUSTDOC=	${WRKDIR}/cargo-home/bin/rustdoc

PLIST_FILES=	share/efi/FreeBSD/zhamel.efi

.include "Makefile.crates"

do-configure:
	${MKDIR} ${RUSTUP_HOME} ${WRKDIR}/cargo-home
	cd ${WRKSRC} && ${SETENVI} ${WRK_ENV} ${MAKE_ENV} \
		HOME=${WRKDIR} \
		CARGO_HOME=${WRKDIR}/cargo-home \
		RUSTUP_HOME=${RUSTUP_HOME} \
		RUSTUP_INIT_SKIP_PATH_CHECK=yes \
		RUSTUP_SELF_UPDATE_DISABLE=1 \
		${LOCALBASE}/bin/rustup-init --profile minimal --default-toolchain none -y
	cd ${WRKSRC} && ${SETENVI} ${WRK_ENV} ${MAKE_ENV} \
		HOME=${WRKDIR} \
		CARGO_HOME=${WRKDIR}/cargo-home \
		RUSTUP_HOME=${RUSTUP_HOME} \
		RUSTUP_SELF_UPDATE_DISABLE=1 \
		${WRKDIR}/cargo-home/bin/rustup toolchain install ${RUSTUP_TOOLCHAIN} \
		--profile minimal --target x86_64-unknown-uefi
	cd ${WRKSRC} && ${SETENVI} ${WRK_ENV} ${MAKE_ENV} \
		HOME=${WRKDIR} \
		CARGO_HOME=${WRKDIR}/cargo-home \
		RUSTUP_HOME=${RUSTUP_HOME} \
		RUSTUP_SELF_UPDATE_DISABLE=1 \
		${WRKDIR}/cargo-home/bin/rustup default ${RUSTUP_TOOLCHAIN}

do-install:
	${MKDIR} ${STAGEDIR}${PREFIX}/share/efi/FreeBSD
	${INSTALL_DATA} ${WRKDIR}/target/x86_64-unknown-uefi/release/zhamel.efi \
		${STAGEDIR}${PREFIX}/share/efi/FreeBSD/zhamel.efi

.include <bsd.port.mk>

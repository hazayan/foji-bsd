PORTNAME=	kunci
DISTVERSION=	0.10.0
CATEGORIES=	sysutils
MASTER_SITES=	https://github.com/hazayan/${PORTNAME}/releases/download/v${DISTVERSION}/
DISTFILES=	${PORTNAME}-v${DISTVERSION}.tar.gz
WRKSRC=		${WRKDIR}/${PORTNAME}-v${DISTVERSION}

MAINTAINER=	yassine@hazayan.dev
COMMENT=	Clevis and Tang implementation for network-bound disk encryption
WWW=		https://github.com/hazayan/kunci

LICENSE=	BSD2CLAUSE
LICENSE_FILE=	${WRKSRC}/LICENSE

USES=		cargo

SUB_FILES=	pkg-message

.if ${ARCH:U${TARGET_ARCH:U}} == amd64
BUILD_DEPENDS=	rustup-init:devel/rustup-init
CARGO_BUILDDEP=	no
CARGO_CONFIGURE=	no
CARGO_ENV+=	RUSTUP_HOME=${RUSTUP_HOME}
RUSTUP_HOME=	${WRKDIR}/rustup-home
RUSTUP_VERSION=	1.95.0
RUSTUP_HOST_TRIPLE=	x86_64-unknown-freebsd
RUSTUP_TOOLCHAIN=	${RUSTUP_VERSION}-${RUSTUP_HOST_TRIPLE}
CARGO=		${WRKDIR}/cargo-home/bin/cargo
RUSTC=		${WRKDIR}/cargo-home/bin/rustc
RUSTDOC=	${WRKDIR}/cargo-home/bin/rustdoc
.endif
CARGO_BUILD_ARGS=	--package kunci-client --package kunci-server --locked
CARGO_INSTALL=	no
CARGO_TEST=	no

PLIST_FILES=	bin/kunci \
		bin/kunci-client \
		bin/kunci-server \
		etc/kunci/kunci.conf.sample \
		etc/rc.d/kunci_zfs

.include "Makefile.crates"

.if ${ARCH:U${TARGET_ARCH:U}} == amd64
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
		--profile minimal
	cd ${WRKSRC} && ${SETENVI} ${WRK_ENV} ${MAKE_ENV} \
		HOME=${WRKDIR} \
		CARGO_HOME=${WRKDIR}/cargo-home \
		RUSTUP_HOME=${RUSTUP_HOME} \
		RUSTUP_SELF_UPDATE_DISABLE=1 \
		${WRKDIR}/cargo-home/bin/rustup default ${RUSTUP_TOOLCHAIN}
.endif

do-install:
	${INSTALL_PROGRAM} ${CARGO_TARGET_DIR}/release/kunci-client \
		${STAGEDIR}${PREFIX}/bin/kunci-client
	${INSTALL_PROGRAM} ${CARGO_TARGET_DIR}/release/kunci-server \
		${STAGEDIR}${PREFIX}/bin/kunci-server
	${LN} -sf kunci-client ${STAGEDIR}${PREFIX}/bin/kunci
	${MKDIR} ${STAGEDIR}${ETCDIR}
	${INSTALL_DATA} ${WRKSRC}/bsd/kunci.conf.example \
		${STAGEDIR}${ETCDIR}/kunci.conf.sample
	${INSTALL_SCRIPT} ${WRKSRC}/bsd/kunci_zfs \
		${STAGEDIR}${PREFIX}/etc/rc.d/kunci_zfs

.include <bsd.port.mk>

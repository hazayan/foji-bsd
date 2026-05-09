PORTNAME=	kunci
DISTVERSION=	0.12.0
CATEGORIES=	sysutils
MASTER_SITES=	https://github.com/hazayan/${PORTNAME}/releases/download/v${DISTVERSION}/
DISTFILES=	${PORTNAME}-v${DISTVERSION}.tar.gz
WRKSRC=		${WRKDIR}/${PORTNAME}-v${DISTVERSION}

MAINTAINER=	yassine@hazayan.dev
COMMENT=	Clevis and Tang implementation for network-bound disk encryption
WWW=		https://github.com/hazayan/kunci

LICENSE=	GPLv3
LICENSE_FILE=	${WRKSRC}/LICENSE

BUILD_DEPENDS=	${LOCALBASE}/llvm20/lib/libclang.so:devel/llvm20
LIB_DEPENDS=	libfido2.so:security/libfido2

USES=		cargo pkgconfig ssl

SUB_FILES=	pkg-message

MAKE_ENV=	LIBCLANG_PATH=${LOCALBASE}/llvm20/lib

CARGO_BUILD_ARGS=	--package kunci-client --package kunci-server \
			--features kunci-server/fido2 --locked
CARGO_INSTALL=	no
CARGO_TEST=	no

PLIST_FILES=	bin/kunci \
		bin/kunci-client \
		bin/kunci-server \
		etc/kunci/kunci.conf.sample \
		etc/rc.d/kunci_zfs

.include "Makefile.crates"

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

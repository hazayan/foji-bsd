PORTNAME=	kunci
DISTVERSION=	0.10.0
CATEGORIES=	sysutils
MASTER_SITES=	https://github.com/hazayan/${PORTNAME}/releases/download/v${DISTVERSION}/
DISTFILES=	${PORTNAME}-v${DISTVERSION}.tar.gz
WRKSRC=		${WRKDIR}/${PORTNAME}-v${DISTVERSION}

MAINTAINER=	ports@FreeBSD.org
COMMENT=	Clevis and Tang implementation for network-bound disk encryption
WWW=		https://github.com/hazayan/kunci

LICENSE=	BSD2CLAUSE
LICENSE_FILE=	${WRKSRC}/LICENSE

USES=		cargo

SUB_FILES=	pkg-message

CARGO_INSTALL_PATH=	client server
CARGO_TEST=	no

PLIST_FILES=	bin/kunci \
		bin/kunci-client \
		bin/kunci-server \
		etc/kunci/kunci.conf.sample \
		etc/rc.d/kunci_zfs

.include "Makefile.crates"

post-install:
	${LN} -sf kunci-client ${STAGEDIR}${PREFIX}/bin/kunci
	${MKDIR} ${STAGEDIR}${ETCDIR}
	${INSTALL_DATA} ${WRKSRC}/bsd/kunci.conf.example \
		${STAGEDIR}${ETCDIR}/kunci.conf.sample
	${INSTALL_SCRIPT} ${WRKSRC}/bsd/kunci_zfs \
		${STAGEDIR}${PREFIX}/etc/rc.d/kunci_zfs

.include <bsd.port.mk>

PORTNAME=	netbird-server
DISTVERSION=	0.70.5
DISTVERSIONPREFIX=	v
CATEGORIES=	security net net-vpn

MAINTAINER=	yassine@hazayan.dev
COMMENT=	Combined NetBird self-hosted server for FreeBSD
WWW=		https://github.com/netbirdio/netbird

LICENSE=	BSD3CLAUSE
LICENSE_FILE=	${WRKSRC}/LICENSE

ONLY_FOR_ARCHS=	amd64

USES=		go:1.25+,modules
USE_RC_SUBR=	netbird_server

GO_MODULE=	github.com/netbirdio/netbird
GO_TARGET=	./combined:${PORTNAME}
GO_BUILDFLAGS=	-tags freebsd -o ${PORTNAME} -ldflags \
		"-s -w -X github.com/netbirdio/netbird/version.version=${DISTVERSION}"
GO_ENV+=	CGO_ENABLED=1

ETCDIR=		${PREFIX}/etc/netbird

SUB_FILES=	netbird-server.yml.sample \
		pkg-message

PLIST_FILES=	bin/${PORTNAME} \
		"@sample ${ETCDIR}/netbird-server.yml.sample"

post-install:
	${MKDIR} ${STAGEDIR}${ETCDIR}
	${INSTALL_DATA} ${WRKDIR}/netbird-server.yml.sample \
		${STAGEDIR}${ETCDIR}/netbird-server.yml.sample

.include <bsd.port.mk>

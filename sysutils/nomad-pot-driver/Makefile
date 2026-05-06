PORTNAME=	nomad-pot-driver
DISTVERSION=	0.10.0
DISTVERSIONPREFIX=	v
PORTREVISION=	1
CATEGORIES=	sysutils

MAINTAINER=	yassine@hazayan.dev
COMMENT=	Nomad task driver for pot jails with dual-stack networking
WWW=		https://github.com/bsdpot/nomad-pot-driver

LICENSE=	APACHE20
LICENSE_FILE=	${WRKSRC}/LICENSE

RUN_DEPENDS=	pot>=0.16.0:sysutils/pot \
		nomad>=1.0:sysutils/nomad

ONLY_FOR_ARCHS=	amd64

USES=		go:1.18+,modules
USE_GITHUB=	yes
GH_ACCOUNT=	bsdpot

GO_MODULE=	github.com/${GH_ACCOUNT}/${PORTNAME}

GO_TARGET=	.:${PREFIX}/libexec/nomad/plugins/${PORTNAME}

PLIST_FILES=	libexec/nomad/plugins/${PORTNAME}

.include <bsd.port.mk>

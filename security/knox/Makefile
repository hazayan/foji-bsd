PORTNAME=	knox
DISTVERSION=	1.3.1
DISTVERSIONPREFIX=	v
CATEGORIES=	security

MAINTAINER=	yassine@hazayan.dev
COMMENT=	Self-hosted secret management service
WWW=		https://github.com/hazayan/knox

LICENSE=	APACHE20
LICENSE_FILE=	${WRKSRC}/LICENSE

ONLY_FOR_ARCHS=	amd64

USES=		go:1.24+,modules
USE_GITHUB=	yes
GH_ACCOUNT=	hazayan

GO_MODULE=	github.com/hazayan/${PORTNAME}
GO_TARGET=	./cmd/client:${PORTNAME} \
		./cmd/server:${PORTNAME}-server \
		./cmd/dbus:${PORTNAME}-dbus

PLIST_FILES=	bin/${PORTNAME} \
		bin/${PORTNAME}-dbus \
		bin/${PORTNAME}-server

.include <bsd.port.mk>

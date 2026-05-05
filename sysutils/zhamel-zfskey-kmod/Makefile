PORTNAME=	zhamel-zfskey
DISTVERSION=	0.10.0
CATEGORIES=	sysutils
PKGNAMESUFFIX=	-kmod

ONLY_FOR_ARCHS= amd64

MAINTAINER=	yassine@hazayan.dev
COMMENT=	Kernel module that loads zhamel-preloaded ZFS wrapping keys
WWW=		https://github.com/hazayan/zhamel-zfskey-kmod

LICENSE=	BSD2CLAUSE
LICENSE_FILE=	${WRKSRC}/LICENSE

USES=		kmod uidfix
KMOD=		zhamel_zfskey

USE_GITHUB=	yes
GH_ACCOUNT=	hazayan
GH_PROJECT=	zhamel-zfskey-kmod
GH_TAGNAME=	v${DISTVERSION}

PLIST_FILES=	${KMODDIR}/zhamel_zfskey.ko

.include <bsd.port.mk>

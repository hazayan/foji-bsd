PORTNAME=	manticore
DISTVERSION=	25.0.0
CATEGORIES=	databases textproc
MASTER_SITES=	https://github.com/manticoresoftware/manticoresearch/archive/refs/tags/:main \
		https://github.com/manticoresoftware/columnar/archive/refs/tags/:columnar \
		https://github.com/RoaringBitmap/CRoaring/archive/refs/tags/:roaring \
		https://github.com/manticoresoftware/snowball/archive/refs/tags/:stemmer
DISTFILES=	${DISTVERSION}${EXTRACT_SUFX}:main \
		${COLUMNAR_TAG}${EXTRACT_SUFX}:columnar \
		v4.3.2.tar.gz:roaring \
		v3.0.3.tar.gz:stemmer
DIST_SUBDIR=	${PORTNAME}
WRKSRC=		${WRKDIR}/manticoresearch-${DISTVERSION}
UID_FILES=	${.CURDIR:H:H}/UIDs ${PORTSDIR}/UIDs
GID_FILES=	${.CURDIR:H:H}/GIDs ${PORTSDIR}/GIDs

MAINTAINER=	ports@FreeBSD.org
COMMENT=	Open source search and analytics database
WWW=		https://manticoresearch.com/

LICENSE=	GPLv3
LICENSE_FILE=	${WRKSRC}/LICENSE

ONLY_FOR_ARCHS=	aarch64 amd64

BUILD_DEPENDS=	bison:devel/bison \
		boost-libs>0:devel/boost-libs \
		flex:textproc/flex \
		nlohmann-json>0:devel/nlohmann-json
LIB_DEPENDS=	libcctz.so:devel/cctz \
		libexpat.so:textproc/expat2 \
		libabsl_base.so:devel/abseil \
		libicuuc.so:devel/icu \
		libmysqlclient.so:databases/mariadb114-client \
		libodbc.so:databases/unixODBC \
		libre2.so:devel/re2 \
		libuni-algo.so:textproc/uni-algo \
		libxxhash.so:devel/xxhash \
		libzstd.so:archivers/zstd \
		libstemmer.so:textproc/snowballstemmer

USES=		perl5 cmake:noninja compiler:c++17-lang cpe iconv localbase:ldflags \
		pgsql pkgconfig ssl

USE_PERL5=	patch build run

USE_RC_SUBR=	${PORTNAME}

USERS=		${PORTNAME}
GROUPS=		${PORTNAME}

CPE_VENDOR=	manticoresearch
WANT_PGSQL=	client

COLUMNAR_TAG=	c27-s19-k12

CMAKE_ARGS=	-DBUILD_TESTING=OFF \
		-DCACHEB=${WRKDIR}/cache \
		-DCMAKE_INSTALL_LOCALSTATEDIR=/var \
		-DCMAKE_INSTALL_RUNSTATEDIR=/var/run \
		-DCMAKE_INSTALL_SYSCONFDIR=etc \
		-DDISTR_BUILD=freebsd \
		-DLIBS_BUNDLE=${DISTDIR}/${DIST_SUBDIR} \
		-DOPENSSL_USE_STATIC_LIBS=OFF \
		-DMYSQL_CONFIG_EXECUTABLE=${LOCALBASE}/bin/mysql_config \
		-DMYSQL_INCLUDE_DIR=${LOCALBASE}/include/mysql \
		-DMYSQL_LIBRARY=${LOCALBASE}/lib/mysql/libmysqlclient.so \
		-DWITH_STEMMER=ON \
                -DSTEMMER_INCLUDE_DIR=${LOCALBASE}/include \
                -DSTEMMER_LIBS=${LOCALBASE}/lib/libstemmer.so \
		-DUSE_SYSLOG=ON \
		-DWITH_CURL=OFF \
		-DWITH_EXPAT=ON \
		-DWITH_GALERA=OFF \
		-DWITH_ICU=ON \
		-DWITH_ICU_FORCE_STATIC=OFF \
		-DWITH_ICONV=ON \
		-DWITH_JIEBA=OFF \
		-DWITH_MYSQL=ON \
		-DWITH_ODBC=ON \
		-DWITH_POSTGRESQL=ON \
		-DWITH_RE2=ON \
		-DWITH_RE2_FORCE_STATIC=OFF \
		-DWITH_SSL=ON \
		-DWITH_STEMMER=ON \
		-DWITH_STEMMER_FORCE_STATIC=OFF \
		-DWITH_ZLIB=ON \
		-DWITH_ZSTD=ON \
		-DDL_EXPAT=ON \
		-DDL_MYSQL=ON \
		-DDL_ODBC=ON \
		-DDL_POSTGRESQL=ON
SUB_LIST=	PORTNAME=${PORTNAME} \
		ETCDIR=${ETCDIR} \
		USERS=${USERS} \
		GROUPS=${GROUPS}

PLIST_SUB=	USERS=${USERS} \
		GROUPS=${GROUPS}

post-patch:
	@${REINPLACE_CMD} \
		-e 's|configure_config ( lib/manticore )|configure_config ( db/manticore )|' \
		-e 's|$${CMAKE_INSTALL_LOCALSTATEDIR}/lib/manticore|$${CMAKE_INSTALL_LOCALSTATEDIR}/db/manticore|' \
		${WRKSRC}/CMakeLists.txt
	@${LOCALBASE}/bin/perl -0pi -e 's|function \( fetch_and_check NAME URL MD5 OUTDIR \)\n|function ( fetch_and_check NAME URL MD5 OUTDIR )\n\tif (EXISTS "\$${URL}")\n\t\tset ( _extract_dir "\$${CMAKE_BINARY_DIR}/_deps/\$${NAME}-extract" )\n\t\tif (NOT EXISTS "\$${_extract_dir}")\n\t\t\tfile ( MAKE_DIRECTORY "\$${_extract_dir}" )\n\t\t\tfile ( ARCHIVE_EXTRACT INPUT "\$${URL}" DESTINATION "\$${_extract_dir}" )\n\t\tendif ()\n\n\t\tfile ( GLOB _extract_children RELATIVE "\$${_extract_dir}" "\$${_extract_dir}/*" )\n\t\tlist ( LENGTH _extract_children _num_extract_children )\n\t\tif (_num_extract_children EQUAL 1 AND IS_DIRECTORY "\$${_extract_dir}/\$${_extract_children}")\n\t\t\tlist ( GET _extract_children 0 _extract_child )\n\t\t\tset ( \$${OUTDIR} "\$${_extract_dir}/\$${_extract_child}" PARENT_SCOPE )\n\t\telse ()\n\t\t\tset ( \$${OUTDIR} "\$${_extract_dir}" PARENT_SCOPE )\n\t\tendif ()\n\n\t\tstring ( TOUPPER "\$${NAME}" UNAME )\n\t\tmark_as_advanced ( FETCHCONTENT_SOURCE_DIR_\$${UNAME} FETCHCONTENT_UPDATES_DISCONNECTED_\$${UNAME} )\n\t\treturn ()\n\tendif ()\n\n|s' ${WRKSRC}/cmake/update_bundle.cmake
	@${REINPLACE_CMD} \
		-e '1s|.*|URL ${DISTDIR}/${DIST_SUBDIR}/${COLUMNAR_TAG}${EXTRACT_SUFX}|' \
		${WRKSRC}/columnar_src.txt

post-install:
	@${MV} ${STAGEDIR}${PREFIX}/etc/manticoresearch/manticore.conf \
		${STAGEDIR}${PREFIX}/etc/manticoresearch/manticore.conf.sample

.include <bsd.port.mk>

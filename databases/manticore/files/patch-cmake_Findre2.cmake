--- cmake/Findre2.cmake.orig	2026-03-27 10:41:53.000000000 +0000
+++ cmake/Findre2.cmake	2026-04-05 03:25:45.151120000 +0000
@@ -35,6 +35,19 @@
 #	set (RE2_INCLUDES "/usr/include;/usr/include/re2" CACHE PATH "path to re2 header files")
 #	set (RE2_LIBRARIES "/usr/lib/x86_64-linux-gnu;/usr/lib64;/usr/local/lib64;/usr/lib/i386-linux-gnu;/usr/lib;/usr/local/lib" CACHE PATH "path to re2 libraries")
 
+find_package ( PkgConfig QUIET )
+if (PkgConfig_FOUND)
+	pkg_check_modules ( PC_RE2 QUIET IMPORTED_TARGET re2 )
+	if (TARGET PkgConfig::PC_RE2)
+		add_library ( re2::re2 INTERFACE IMPORTED )
+		target_link_libraries ( re2::re2 INTERFACE PkgConfig::PC_RE2 )
+		set ( RE2_FOUND TRUE )
+		set ( RE2_INCLUDE_DIRS "${PC_RE2_INCLUDE_DIRS}" )
+		set ( RE2_LIBRARY "${PC_RE2_LINK_LIBRARIES}" )
+		return ()
+	endif ()
+endif ()
+
 function ( check_re2 HINT )
 	if (RE2_LIBRARY AND NOT EXISTS ${RE2_LIBRARY})
 		unset ( RE2_LIBRARY CACHE )

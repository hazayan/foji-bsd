--- cmake/GetxxHash.cmake.orig	2026-03-27 10:33:06 UTC
+++ cmake/GetxxHash.cmake
@@ -9,6 +9,22 @@
 include ( update_bundle )
 
 # determine destination folder where we expect pre-built xxhash
+find_package ( PkgConfig QUIET )
+if (PkgConfig_FOUND)
+	pkg_check_modules ( PC_XXHASH QUIET libxxhash )
+	if (PC_XXHASH_FOUND AND NOT TARGET xxHash::xxhash)
+		find_library ( XXHASH_LIBRARY NAMES xxhash HINTS ${PC_XXHASH_LIBRARY_DIRS} )
+		if (XXHASH_LIBRARY)
+			add_library ( xxHash::xxhash UNKNOWN IMPORTED )
+			set_target_properties ( xxHash::xxhash PROPERTIES
+					IMPORTED_LOCATION "${XXHASH_LIBRARY}"
+					INTERFACE_INCLUDE_DIRECTORIES "${PC_XXHASH_INCLUDE_DIRS}"
+					)
+		endif ()
+	endif ()
+endif ()
+return_if_target_found ( xxHash::xxhash "found via pkg-config" )
+
 find_package ( xxHash QUIET CONFIG )
 return_if_target_found ( xxHash::xxhash "found ready (no need to build)" )
 

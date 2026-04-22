--- cmake/GetRBitmap.cmake.orig	2026-03-27 10:33:06 UTC
+++ cmake/GetRBitmap.cmake
@@ -1,7 +1,7 @@
 cmake_minimum_required ( VERSION 3.17 FATAL_ERROR )
 
 set ( ROARINGBITMAP_GITHUB "https://github.com/RoaringBitmap/CRoaring/archive/refs/tags/v4.3.2.tar.gz" )
-set ( ROARINGBITMAP_BUNDLE "${LIBS_BUNDLE}/roaring-v4.3.2.tar.gz" )
+set ( ROARINGBITMAP_BUNDLE "${LIBS_BUNDLE}/v4.3.2.tar.gz" )
 set ( ROARINGBITMAP_SRC_MD5 "9ad3047cd74e5a3562c30f7c8a606373" )
 
 include ( update_bundle )

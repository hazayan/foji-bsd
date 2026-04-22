--- cmake/GetSTEMMER.cmake.orig	2026-03-27 10:33:06 UTC
+++ cmake/GetSTEMMER.cmake
@@ -10,14 +10,14 @@
 #=============================================================================
 # This file need to get libstemmer sources
 # First it try 'traditional' way - find stemmer package.
-# Then (if it is not found) it try to look into ${LIBS_BUNDLE} for file named 'libstemmer_c.tgz'
+# Then (if it is not found) it try to look into ${LIBS_BUNDLE} for file named 'v3.0.3.tar.gz'
 # It is supposed, that file (if any) contains archive from snowball with stemmer's sources.
 # If no file found, it will try to fetch it from
-# https://snowballstem.org/dist/libstemmer_c.tgz
+# https://github.com/manticoresoftware/snowball/archive/refs/tags/v3.0.3.tar.gz
 
 set ( STEMMER_REMOTE "https://github.com/manticoresoftware/snowball/archive/refs/tags/v3.0.3.tar.gz" )
-set ( STEMMER_BUNDLEZIP "${LIBS_BUNDLE}/libstemmer_c.tgz" )
+set ( STEMMER_BUNDLEZIP "${LIBS_BUNDLE}/v3.0.3.tar.gz" )
 set ( STEMMER_SRC_MD5 "4fec9f845790b1758175bd16e06e4fe6" )
 
 cmake_minimum_required ( VERSION 3.17 FATAL_ERROR )

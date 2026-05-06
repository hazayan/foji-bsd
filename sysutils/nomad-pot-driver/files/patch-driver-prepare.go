--- driver/prepare.go.orig	2026-05-06 16:00:00.000000000 +0000
+++ driver/prepare.go	2026-05-06 16:00:00.000000000 +0000
@@ -36,7 +36,7 @@
 	se.env = cfg.EnvList()
 
 	// action can be run/exec
 
-	argv = append(argv, "prepare", "-U", taskCfg.Image, "-p", taskCfg.Pot, "-t", taskCfg.Tag)
+	argv = append(argv, "prepare", "-U", taskCfg.Image, "-p", taskCfg.Pot, "-t", taskCfg.Tag, "-S", "dual")
 
 	if len(taskCfg.Args) > 0 {
 		if taskCfg.Command == "" {

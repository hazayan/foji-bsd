--- driver/pot.go.orig	2026-05-06 20:52:00 UTC
+++ driver/pot.go
@@ -553,7 +553,7 @@ func (s *syexec) execInContainer(ctx context.Context, commandCfg *drivers.TaskConfig,
 	}
 
 	execResult.ExitResult.ExitCode = s.exitCode
-	s.logger.Debug(fmt.Sprintf("ExecInContainer command exit code %i", execResult.ExitResult.ExitCode))
+	s.logger.Debug(fmt.Sprintf("ExecInContainer command exit code %d", execResult.ExitResult.ExitCode))
 	s.logger.Debug(string(execResult.Stdout))
 	s.logger.Debug(string(execResult.Stderr))
 	return execResult, nil

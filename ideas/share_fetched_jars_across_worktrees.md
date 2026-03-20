# share fetched jars across worktrees

**Timestamp:** 2026-02-03 06:49:02 UTC
**Issued from:** `/Users/paulbaernreuther/ai/framework`

## Idea

The ticket-fetch-jars mechanism runs mvn clean package for each plugin's lib/fetch_jars/ in every worktree. Since the same JARs are downloaded repeatedly for the same plugin across different worktrees/branches, we could speed this up by: (1) having a central JAR cache directory, (2) symlinking or copying from cache instead of re-downloading, or (3) using Maven's local repository more intelligently. This would significantly reduce fetch time when switching between tickets that use the same plugins.

# view staged file in vscode

**Timestamp:** 2026-02-11 14:23:47 UTC
**Issued from:** `/Users/paulbaernreuther/KNIME/repos/knime-ui-table`

## Idea

To open the staged (index) version of a file in VS Code, use: git show :path/to/file > /tmp/filename.staged.ext && code /tmp/filename.staged.ext. This is useful when the working tree differs from staged content and you need to inspect or lint only what will be committed.

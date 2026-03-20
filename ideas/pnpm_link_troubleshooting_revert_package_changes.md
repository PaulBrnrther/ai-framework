# pnpm link troubleshooting revert package changes

**Timestamp:** 2026-02-04 18:10:37 UTC
**Issued from:** `/Users/paulbaernreuther/knime/repos/knime-core-ui.git/branches/enh/UIEXT-3141-table-creator-webui/js-src/packages/core-ui`

## Idea

When pnpm links between repos stop working (e.g. knime-ui-table linked into knime-core-ui), the fix is often to revert any local changes to package.json and pnpm-lock.yaml, then re-run pnpm install. The pnpm-workspace.yaml overrides handle the linking — modifying package.json dependency entries or the lockfile directly can break the link resolution. When debugging broken links: first check git diff on package.json and pnpm-lock.yaml, revert those changes, and reinstall before investigating further.

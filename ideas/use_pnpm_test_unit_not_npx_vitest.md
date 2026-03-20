# use pnpm test unit not npx vitest

**Timestamp:** 2026-02-17 09:16:02 UTC
**Issued from:** `/Users/paulbaernreuther/knime/repos/knime-core-ui.git/branches/enh/UIEXT-3141-table-creator-webui/js-src/packages/core-ui`

## Idea

In knime-core-ui and similar monorepo packages, always run tests via 'pnpm test:unit --run' from the package directory (e.g. js-src/packages/core-ui) instead of 'npx vitest run'. Running npx vitest directly bypasses the vitest config that handles .vue file compilation and external component imports (like @knime/kds-components), causing 'Failed to parse source for import analysis' errors.

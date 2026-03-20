# slash command delegate frontend unit tests

**Timestamp:** 2026-02-10 11:05:06 UTC
**Issued from:** `/Users/paulbaernreuther/KNIME/repos/knime-core-ui/js-src/packages/core-ui`

## Idea

Create a slash command (e.g. /test-composables or /unit-tests) that automates delegating unit test writing to subagents for frontend composables/modules. It should: (1) auto-discover untested files in a given directory, (2) read each file and dispatch parallel subagents with the source code inlined to save tokens, (3) include project-specific knowledge like using --run flag with pnpm test:unit to prevent watch mode, (4) know the test pattern (vitest, describe/it/expect), (5) run tests with coverage after writing, and (6) collect results and fix failures. This was inspired by a session where manually coordinating 8 parallel test-writing agents required significant upfront context gathering and the agents kept being killed because they didn't know about --run or tried to search for irrelevant type definitions.

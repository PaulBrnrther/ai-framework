# mvn test run knime-core-ui

**Timestamp:** 2026-02-25 00:00:00 UTC
**Issued from:** `/Users/paulbaernreuther/knime/repos/knime-core-ui`

## Idea

To run Java tests in knime-core-ui, use `mvn verify` with the test profile:

```bash
cd /Users/paulbaernreuther/knime/repos/knime-core-ui && mvn verify -Ptest -DskipUITests -Dtest=DefaultNodeDialogWidgetTest -DfailIfNoTests=false -pl :org.knime.core.ui,:org.knime.core.ui.testing,:org.knime.core.ui.tests 2>&1 | tail -200
```

Key flags:
- `-Ptest` — activates the test profile
- `-DskipUITests` — skips UI tests, runs only unit tests
- `-Dtest=ClassName` — run a specific test class (replace as needed)
- `-DfailIfNoTests=false` — don't fail if no tests found in a module
- `-pl :org.knime.core.ui,:org.knime.core.ui.testing,:org.knime.core.ui.tests` — target modules

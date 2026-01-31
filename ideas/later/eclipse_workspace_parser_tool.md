# eclipse workspace parser tool

**Timestamp:** 2026-01-29 15:40:42 UTC
**Issued from:** `/Users/paulbaernreuther/KNIME/repos`

## Idea

We reverse-engineered Eclipse's binary .tree file format (ElementTree/DeltaDataTree) to programmatically detect which projects are open vs closed in an Eclipse workspace from outside the IDE. A working parser exists at ~/ai/eclipse-workspace-parser/parse_open_projects.py. Next steps: (1) Add delta chain replay so it works without requiring an Eclipse restart - currently only reads the base tree, but the current state requires applying all deltas in the chain. (2) Package as a reusable CLI tool. (3) Integrate into Claude Code workflow to auto-detect open projects in the user's Eclipse IDE, enabling context-aware assistance (e.g. only indexing/searching open projects). Key technical insight: both the writer and reader skip ROOT node element data (data flag is written as 1 but no bytes follow), which was the hardest part to figure out.

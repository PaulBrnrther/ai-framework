# xml snapshot comparison context

**Timestamp:** 2026-01-28 09:42:14 UTC
**Issued from:** `/Users/paulbaernreuther/KNIME/repos/knime-bigdata`

## Idea

Create a loadable context (not default) for comparing XML snapshot test outputs against node settings input XML files. It should understand the structure (model vs internal settings, type_mapping sections), know to ignore *_Internals configs, and efficiently diff the roundtrip result against the original input highlighting semantic differences (defaults being written back, field value changes, missing/extra fields). Useful for KNIME node parameter migration work where settings XML roundtrip fidelity needs verification.

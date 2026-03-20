# cl fzf tab switcher

**Timestamp:** 2026-03-07 07:25:45 UTC
**Issued from:** `/Users/paulbaernreuther/ai/framework`

## Idea

After cl clears idle terminal tabs and browser tabs, show an fzf picker to switch to one of the remaining Terminal.app tabs. Each entry should show the custom title and current working directory (looked up via lsof on the tty's shell PID). Selecting an entry activates the corresponding window/tab via AppleScript. The scaffolding already exists in tab-clear but is gated behind exit 0 — the bash while-loop enrichment under set -euo pipefail needs debugging (ps/lsof failures silently killing the loop).

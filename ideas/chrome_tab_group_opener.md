# Chrome Tab Group Opener

Goal: open URLs (PRs, Jira tickets, Jenkins builds, …) from the terminal into named Chrome tab groups, one group per ticket.

## What We Built (Prototype)

Files: `~/chrome-tab-manager/`

```
manifest.json   – Chrome extension (MV3)
background.js   – service worker: connects to native host, calls openInGroup()
host.py         – native messaging host: reads FIFO, forwards to extension
install.sh      – installs native host manifest + sets permissions
```

Extension ID: `mocoldahclepimncmbdofeifillljfkm`
Native host name: `com.knime.tabmanager`
FIFO path: `~/.tab-manager.fifo`
Native host manifest: `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.knime.tabmanager.json`

### Shell Usage

Single tab:
```bash
echo '{"url":"https://github.com","group":"UIEXT-1234 Fix the koala bug","color":"blue"}' > ~/.tab-manager.fifo
```

Multiple tabs at once (single FIFO write — sequential writes race):
```bash
printf '{"url":"%s","group":"UIEXT-1234 Fix the koala bug","color":"blue"}\n' \
  "https://github.com/pr/1" \
  "https://jira.knime.com/browse/UIEXT-1234" \
  "https://jenkins.example.com/job/1234" > ~/.tab-manager.fifo
```

## Bugs Found & Fixed

1. **"Tabs can only be moved to and from normal windows"** (on `chrome.tabs.group`)
   Cause: without `createProperties`, Chrome creates the group in the currently focused window — which is the DevTools window when calling from the service worker console.
   Fix: always pass `createProperties: { windowId: tab.windowId }`.

2. **Tab created in DevTools window** (on `chrome.tabs.create`)
   Cause: `chrome.tabs.create({ url })` without `windowId` lands in the focused window (DevTools).
   Fix: fetch normal windows first, pass `windowId` explicitly.

3. **Multiple FIFO writes in a loop fail**
   Cause: FIFO blocks on open until a reader is ready; the Python thread can't reopen fast enough between iterations.
   Fix: write all lines in a single `printf ... > fifo` call so the reader processes them in one open.

## Architecture

```
terminal command
  → write JSON line(s) to ~/.tab-manager.fifo
    → host.py FIFO thread reads, sends via native messaging protocol (4-byte LE length + JSON)
      → background.js port.onMessage fires
        → openInGroup(url, group, color)
          → chrome.windows.getAll({ windowTypes: ["normal"] })
          → chrome.tabs.create({ url, windowId })
          → chrome.tabs.query({}) + filter by tab.url       ← use manual filter, not query({url}) — requires match pattern not literal URL
          → chrome.tabGroups.query({}) + filter by title   ← use manual filter, not query({title})
          → chrome.tabs.group({ tabIds, groupId or createProperties: { windowId } })
          → chrome.tabGroups.update(groupId, { title, color })
```

The native messaging connection keeps the MV3 service worker alive (active port = no idle termination). If Chrome restarts, the service worker reconnects to the host with a 2s retry loop.

## Tab Group API Limits

Only 4 things are settable on a group (`chrome.tabGroups.update`):
- `title` – any string
- `color` – `grey` `blue` `red` `yellow` `green` `pink` `purple` `cyan` `orange` (9 options, no custom)
- `collapsed` – boolean

Tab favicons cannot be set by extensions — they come from the page.

## Known Issues

- **Chrome 145 rendering bug**: `chrome.tabGroups.update()` sets the title correctly in the API but Chrome 145 does not render it visually in the tab strip. Collapse/uncollapse workarounds do not help. Use Chromium 116 (`~/Downloads/chrome-mac/chrome-mac/Chromium.app`) instead — launch with `--remote-debugging-port=9222` if needed. Title rendering works correctly there.

## Next Steps

- Move prototype into `commands/` when ready
- Create a `tab-group` helper that `ticket-pr`, `ticket-jira`, `ticket-jenkins` etc. can all call
- Map ticket ID → color deterministically (e.g. hash ticket number mod 9)
- Handle the case where Chrome is not running (FIFO write hangs — add timeout)
- Possibly collapse groups for inactive tickets on `ticket switch`

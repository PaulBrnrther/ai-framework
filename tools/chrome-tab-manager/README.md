# Chrome Tab Manager

A Chrome extension + native messaging host that lets you open URLs in named tab groups and query/close tabs from the terminal.

## Installation

### 1. Load the extension in Chrome

1. Open `chrome://extensions/`
2. Enable **Developer mode** (top right)
3. Click **Load unpacked** and select this directory (`tools/chrome-tab-manager/`)
4. Note the extension ID shown on the card

### 2. Update the extension ID

If the extension ID differs from what's in `install.sh`, edit the `allowed_origins` line:

```
"allowed_origins": ["chrome-extension://<YOUR_EXTENSION_ID>/"]
```

### 3. Install the native messaging host

```bash
./install.sh
```

This registers `com.knime.tabmanager` as a native messaging host by writing a manifest to `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/`.

### 4. Reload the extension

Go back to `chrome://extensions/` and click the reload button on the extension card. The background service worker will connect to the native host automatically.

## Usage

The extension communicates via a FIFO at `~/.tab-manager.fifo`. Send JSON commands by writing to it.

### Open a URL in a tab group

```bash
echo '{"url":"https://example.com","group":"My Group","color":"blue"}' > ~/.tab-manager.fifo
```

- **url** — the URL to open (reuses an existing tab if the URL is already open)
- **group** — tab group name (creates the group if it doesn't exist)
- **color** — optional, one of: `grey`, `blue`, `red`, `yellow`, `green`, `pink`, `purple`, `cyan`, `orange` (default: `blue`)

This also collapses all other tab groups and focuses the opened tab.

### List all tabs and groups

```bash
echo '{"action":"list","response_file":"/tmp/tabs.json"}' > ~/.tab-manager.fifo
cat /tmp/tabs.json
```

The response is written to `response_file` and contains `{ "tabs": [...], "groups": [...] }`.

### Close tabs by ID

```bash
echo '{"action":"close","tabIds":[123,456]}' > ~/.tab-manager.fifo
```

## Troubleshooting

- **Logs**: `~/.tab-manager.log` — shows all FIFO input, messages sent to Chrome, and responses
- **"Access to the specified native messaging host is forbidden"**: The extension ID in the installed manifest doesn't match. Re-run `install.sh` after updating the ID, then reload the extension.
- **Extension disconnects**: The service worker reconnects automatically after 2 seconds. A keepalive alarm prevents Chrome from killing it.

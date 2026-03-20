#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOST_MANIFEST_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"

chmod +x "$SCRIPT_DIR/host.py"

mkdir -p "$HOST_MANIFEST_DIR"

cat > "$HOST_MANIFEST_DIR/com.knime.tabmanager.json" <<EOF
{
  "name": "com.knime.tabmanager",
  "description": "Tab group manager",
  "path": "$SCRIPT_DIR/host.py",
  "type": "stdio",
  "allowed_origins": ["chrome-extension://nngchpbofkfcmanmcnadhjdmpigbjhhh/"]
}
EOF

echo "Installed. Now reload the extension in chrome://extensions."

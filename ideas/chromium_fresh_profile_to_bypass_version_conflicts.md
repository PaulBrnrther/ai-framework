# chromium fresh profile to bypass version conflicts

**Timestamp:** 2026-02-22 09:37:41 UTC
**Issued from:** `/Users/paulbaernreuther/Downloads/chrome-mac 5`

## Idea

When Chromium freezes or crashes due to profile data written by a newer version, launch with a clean profile: open -a "/path/to/Chromium.app" --args --password-store=basic --use-mock-keychain --user-data-dir=/tmp/chromium-fresh-profile

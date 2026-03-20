async function openInGroup(url, groupName, color = "blue") {
  const windows = await chrome.windows.getAll({ windowTypes: ["normal"] });
  if (windows.length === 0) throw new Error("No normal browser window open");
  const windowId = windows[windows.length - 1].id;

  // Manual filter — tabs.query({ url }) requires a match pattern, not a literal URL
  const allTabs = await chrome.tabs.query({});
  const existing = allTabs.filter(t => t.url === url);
  const tab = existing.length > 0
    ? existing[0]
    : await chrome.tabs.create({ url, windowId });

  // Manual title filter — tabGroups.query({ title }) is unreliable in Chrome
  const allGroups = await chrome.tabGroups.query({});
  const matchingGroup = allGroups.find(g => g.title === groupName);

  if (matchingGroup) {
    if (tab.groupId !== matchingGroup.id) {
      await chrome.tabs.group({ tabIds: [tab.id], groupId: matchingGroup.id });
    }
  } else {
    const groupId = await chrome.tabs.group({
      tabIds: [tab.id],
      createProperties: { windowId: tab.windowId },
    });
    await chrome.tabGroups.update(groupId, { title: groupName, color });
  }

  await chrome.tabs.update(tab.id, { active: true });
  await chrome.windows.update(tab.windowId, { focused: true });

  // Collapse all other groups
  const finalGroups = await chrome.tabGroups.query({});
  const activeGroup = finalGroups.find(g => g.title === groupName);
  await Promise.all(
    finalGroups
      .filter(g => g.id !== activeGroup?.id && !g.collapsed)
      .map(g => chrome.tabGroups.update(g.id, { collapsed: true }))
  );
}

function connect() {
  const port = chrome.runtime.connectNative("com.knime.tabmanager");

  port.onMessage.addListener((msg) => {
    if (msg.action === "list") {
      Promise.all([
        chrome.tabs.query({}),
        chrome.tabGroups.query({}),
      ]).then(([tabs, groups]) => {
        port.postMessage({ tabs, groups });
      }).catch(console.error);
    } else if (msg.action === "close") {
      chrome.tabs.remove(msg.tabIds || []).then(async () => {
        const windows = await chrome.windows.getAll({ windowTypes: ["normal"] });
        if (windows.length > 0) {
          await chrome.windows.update(windows[windows.length - 1].id, { focused: true });
        }
      }).catch(console.error);
    } else {
      openInGroup(msg.url, msg.group, msg.color || "blue").catch(console.error);
    }
  });

  port.onDisconnect.addListener(() => {
    setTimeout(connect, 2000);
  });
}

connect();

// Keep the service worker alive — MV3 workers are killed after ~30s idle.
chrome.alarms.create("keepalive", { periodInMinutes: 0.4 });
chrome.alarms.onAlarm.addListener(() => {});

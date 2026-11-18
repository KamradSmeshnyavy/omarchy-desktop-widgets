pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Его shared/HyprShared.qml — то, что берёт звёздная карта. Диспетчеры — Lua-выражения Hyprland, как у него.
Singleton {
  readonly property string home: Quickshell.env("HOME")
  function focusWs(id) { Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })") }
  function focusWindow(a) { a = String(a); Hyprland.dispatch("hl.dsp.focus({ window = \"address:" + (a.startsWith("0x") ? a : "0x" + a) + "\" })") }
  function focusedScreen() {
    return Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
  }
  readonly property var moonScreen: Quickshell.screens.reduce((a, b) => b.width > a.width ? b : a, Quickshell.screens[0])
  function rateOf(screen) { return Hyprland.monitorFor(screen)?.lastIpcObject?.refreshRate ?? 0 }
  readonly property var fastScreen: Quickshell.screens.reduce((a, b) => rateOf(b) > rateOf(a) + 1 ? b : a, Quickshell.screens[0])
  readonly property real fastMs: 1000 / (rateOf(fastScreen) || 60)
  Component.onCompleted: Hyprland.refreshMonitors()
}

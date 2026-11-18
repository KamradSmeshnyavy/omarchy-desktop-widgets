pragma Singleton

import QtQuick
import Quickshell
import qs.Commons as Commons

// Его Space/common/Theme.qml (ThemeBaseShared) — только то, что берёт звёздная карта; цвета — из темы Omarchy.
Singleton {
  readonly property color accent: Commons.Color.accent
  readonly property color fg: Commons.Color.foreground
  readonly property color bg: Commons.Color.background
  readonly property color accent2: mix(accent, fg, 0.45)
  readonly property color dim: alpha(fg, 0.5)
  readonly property string font: Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : "monospace"
  readonly property var settle: [0.2, 0.9, 0.3, 1, 1, 1]
  function alpha(c, a) { c = Qt.color(c); return Qt.rgba(c.r, c.g, c.b, a) }
  function mix(a, b, t) { a = Qt.color(a); b = Qt.color(b); return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1) }
  function back(a) { return alpha(bg, a) }
  function ms(d) { return d }
  function slotOf(role) { return 9 }
  function readable(c) { return Qt.color(c) }
  function c(i, fallback) { return fallback }
}

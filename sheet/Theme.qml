pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons

// Его ThemeBaseShared + Space/common/Theme.qml — то, что берёт панель Sheet. Цвета — тема Omarchy. Облик по райсу
// (style.json "rice"): Space — как у него (JetBrains Mono, капс, разрядка 1.6, прямые углы); остальные — шрифт
// оболочки, обычный регистр, скругление.
Singleton {
  id: th
  property string rice: ""
  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/style.json"
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { try { var s = JSON.parse(text()); th.rice = String(s.rice || s.id || "") } catch (e) {} }
  }
  readonly property bool hud: rice === "space" || rice === "crt"
  readonly property color accent: Commons.Color.accent
  readonly property color fg: Commons.Color.foreground
  readonly property color bg: Commons.Color.background
  readonly property color dim: alpha(fg, 0.5)
  readonly property color faint: alpha(fg, 0.14)
  readonly property color bright: fg
  readonly property color edge: alpha(accent, 0.35)
  readonly property string mono: Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : "monospace"
  // Retro CRT — Terminess, как у него в Retro/common/Theme.qml
  readonly property string term: Qt.fontFamilies().indexOf("Terminess Nerd Font Mono") !== -1 ? "Terminess Nerd Font Mono" : mono
  readonly property string font: rice === "crt" ? term : hud ? mono : (Commons.Style && Commons.Style.font ? Commons.Style.font.family : mono)
  readonly property string sans: font
  readonly property int caps: hud ? Font.AllUppercase : Font.MixedCase
  readonly property real tracking: rice === "crt" ? 1 : hud ? 1.6 : 0.4
  readonly property real lines: 1
  readonly property real round: hud ? 0 : 1
  readonly property real rounding: hud ? 0 : 10
  readonly property int pad: 14
  function r(px) { return px * rounding / 10 }
  readonly property var settle: [0.2, 0.9, 0.3, 1, 1, 1]
  readonly property var leave: [0.4, 0, 0.6, 1, 1, 1]
  readonly property int fast: 160
  readonly property int quick: 180
  readonly property int move: 280
  readonly property int slow: 560
  function ms(d) { return d }
  function alpha(c, a) { c = Qt.color(c); return Qt.rgba(c.r, c.g, c.b, a) }
  function mix(a, b, t) { a = Qt.color(a); b = Qt.color(b); return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1) }
  function back(a) { return alpha(bg, a) }
}

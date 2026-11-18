import QtQuick
import qs.Commons as Commons

// Цвета и шрифт Retro CRT для виджетов (по его Retro/common/Theme.qml, elifouts/Dotfiles, GPL-3.0): фон темы, текст,
// акцент — цвет трубки, dim — текст 50 %, low — акцент 18 % (подложка), line — акцент 55 % (рамки). Terminess, 14 px.
QtObject {
  readonly property color bg: Commons.Color.background
  readonly property color fg: Commons.Color.foreground
  readonly property color accent: Commons.Color.accent
  readonly property color warn: Commons.Color.urgent
  readonly property color dim: Qt.rgba(fg.r, fg.g, fg.b, 0.5)
  readonly property color low: Qt.rgba(accent.r, accent.g, accent.b, 0.18)
  readonly property color line: Qt.rgba(accent.r, accent.g, accent.b, 0.55)
  readonly property color edge: Qt.rgba(accent.r, accent.g, accent.b, 0.45)
  readonly property string font: Qt.fontFamilies().indexOf("Terminess Nerd Font Mono") !== -1 ? "Terminess Nerd Font Mono" : "monospace"
  readonly property int size: 14
  function a(c, k) { return Qt.rgba(c.r, c.g, c.b, k) }
}

import QtQuick

// Текст Retro CRT (его Retro/common/Type.qml, elifouts/Dotfiles, GPL-3.0): капсом вразрядку, при смене «печатается»
// слева направо с курсором █ за min(320, 40 + 12·длина) мс. type: false — без печати (тикающие значения).
Item {
  id: t
  property string text
  property var pal: null
  property bool type: true
  property bool caps: true
  property alias font: label.font
  property alias color: label.color
  property alias elide: label.elide
  property alias horizontalAlignment: label.horizontalAlignment
  property real n: 1e6
  implicitWidth: Math.ceil(tm.advanceWidth) + 1
  implicitHeight: label.implicitHeight
  TextMetrics { id: tm; font: label.font; text: t.caps ? t.text.toUpperCase() : t.text }
  function run() {
    if (!type || !visible) { tick.stop(); n = 1e6; return }
    tick.to = text.length + 1
    tick.duration = Math.min(320, 40 + text.length * 12)
    tick.restart()
  }
  onTextChanged: run()
  Component.onCompleted: run()
  NumberAnimation { id: tick; target: t; property: "n"; from: 0; onRunningChanged: if (!running) t.n = 1e6 }
  Text {
    id: label
    anchors.fill: parent
    text: t.n > t.text.length ? t.text : t.text.slice(0, Math.floor(t.n)) + "█"
    font.family: t.pal ? t.pal.font : "monospace"
    font.pixelSize: t.pal ? t.pal.size : 14
    font.letterSpacing: t.caps ? 1 : 0
    font.capitalization: t.caps ? Font.AllUppercase : Font.MixedCase
    color: t.pal ? t.pal.fg : "white"
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
  }
}

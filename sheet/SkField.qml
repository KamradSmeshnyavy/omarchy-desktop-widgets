import QtQuick

// Поле ввода в облике (поиск шрифтов, «сохранить как»). Esc отдаёт фокус панели (Sk.keys), Enter — accepted.
Rectangle {
  id: f
  property alias text: input.text
  property string placeholder
  signal accepted()
  function grab() { input.forceActiveFocus() }
  readonly property bool editing: input.activeFocus
  width: 260
  height: 26
  radius: Sk.n("radius", 4)
  color: Sk.alpha(Sk.c("ink"), 0.06)
  border.width: Math.max(1, Sk.n("border", 1))
  border.color: input.activeFocus ? Sk.c("accent") : Sk.alpha(Sk.c("ink"), 0.25)
  TextInput {
    id: input
    anchors.fill: parent
    anchors.leftMargin: 8; anchors.rightMargin: 8
    verticalAlignment: TextInput.AlignVCenter
    color: Sk.c("ink")
    selectionColor: Sk.c("accent")
    font.family: Sk.s("font", "monospace"); font.pixelSize: Sk.n("size", 12)
    clip: true
    Keys.onEscapePressed: e => { if (Sk.keys) Sk.keys.forceActiveFocus(); e.accepted = true }
    Keys.onTabPressed: e => { if (Sk.keys) Sk.keys.forceActiveFocus(); e.accepted = true }
    onAccepted: f.accepted()
  }
  Text {
    x: 8; anchors.verticalCenter: parent.verticalCenter
    visible: !input.text
    text: f.placeholder
    color: Sk.alpha(Sk.c("ink"), 0.35)
    font.family: Sk.s("font", "monospace"); font.pixelSize: Sk.n("size", 12)
  }
  // клик / Enter с клавиатуры (KeyNav) — начать ввод
  SkHit {
    anchors.fill: parent
    enabled: !input.activeFocus
    cursorShape: Qt.IBeamCursor
    kbdRadius: Sk.n("radius", 4)
    onHit: input.forceActiveFocus()
  }
}

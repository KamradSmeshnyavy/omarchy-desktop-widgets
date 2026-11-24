import QtQuick

// Выбор строкой. Немного коротких вариантов — рядом кнопками (←/→ по ним, Enter — выбрать); много или длинные —
// значение с «▾»: Enter / клик открывают выпадающий список со всеми (Sk.list), применяется только выбранное.
// Вид кнопок — Sk.t.chip: fill (заливка акцентом), underline, bracket ([выбранный] у yami), invert.
Item {
  id: pk
  property string label
  property var options: []
  property var current
  property bool dropdown: false        // всегда списком (Rice, Variant, Bar)
  signal chose(var v)
  readonly property string chip: Sk.s("chip", "fill")
  readonly property real labelW: Sk.n("labelW", 150)
  function lbl(o) { return String(o && o.l !== undefined ? o.l : o) }
  function val(o) { return o && o.v !== undefined ? o.v : o }
  readonly property var curOpt: options.find(o => val(o) === current)
  readonly property real chipsW: options.reduce((n, o) => n + lbl(o).length * Sk.n("size", 12) * 0.66 + 22, 0)
  readonly property bool list: dropdown || options.length > 5 || chipsW > width - labelW
  readonly property string rowLabel: label
  readonly property string rowValue: curOpt ? lbl(curOpt) : ""
  readonly property string rowHint: list ? "Enter — open the list · ↑↓ — choose · Enter — apply · Esc — cancel" : "← → — move · Enter — choose"
  width: 320
  implicitHeight: Math.max(24, Sk.n("rowH", 26))
  function openList() { if (Sk.list) Sk.list.open(btn, options, current, v => pk.chose(v), label) }

  SkLabel { width: pk.labelW - 8; height: parent.height; text: pk.label }

  // значение с «▾»
  Item {
    id: btn
    visible: pk.list
    x: pk.labelW
    width: pk.width - pk.labelW
    height: parent.height
    Rectangle {
      anchors.fill: parent
      anchors.topMargin: 2; anchors.bottomMargin: 2
      visible: Sk.s("chip", "fill") !== "bracket"
      radius: Sk.n("radius", 4)
      color: bm.containsMouse ? Sk.alpha(Sk.c("accent"), 0.16) : Sk.alpha(Sk.c("ink"), 0.05)
      border.width: Sk.n("border", 1)
      border.color: Sk.alpha(Sk.c("ink"), 0.25)
    }
    Text {
      x: 8; width: parent.width - 30
      anchors.verticalCenter: parent.verticalCenter
      elide: Text.ElideRight
      text: pk.chip === "bracket" ? "<" + pk.rowValue + ">" : Sk.cap(pk.rowValue || "—")
      color: Sk.c("accent")
      font.family: Sk.s("font", "monospace"); font.pixelSize: Sk.n("size", 12); font.letterSpacing: Sk.n("spacing", 0)
    }
    Text {
      anchors.right: parent.right; anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      text: pk.chip === "bracket" ? "^n" : "▾"
      color: Sk.c("dim")
      font.family: Sk.s("font", "monospace"); font.pixelSize: Sk.n("size", 12)
    }
    SkHit {
      id: bm
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      kbdRadius: Sk.n("radius", 4)
      onHit: pk.openList()
    }
  }

  // кнопки
  Row {
    visible: !pk.list
    x: pk.labelW
    height: parent.height
    spacing: 6
    Repeater {
      model: pk.list ? [] : pk.options
      Item {
        id: c
        required property var modelData
        readonly property bool on: pk.val(modelData) === pk.current
        width: word.implicitWidth + 16
        height: pk.height
        Rectangle {
          anchors.fill: parent
          anchors.topMargin: 3; anchors.bottomMargin: 3
          radius: Sk.n("radius", 4)
          visible: pk.chip === "fill" || pk.chip === "invert"
          color: c.on ? (pk.chip === "invert" ? Sk.c("ink") : Sk.c("accent")) : cm.containsMouse ? Sk.alpha(Sk.c("ink"), 0.08) : "transparent"
          border.width: pk.chip === "fill" && !c.on ? Sk.n("border", 1) : 0
          border.color: Sk.alpha(Sk.c("ink"), 0.22)
        }
        Rectangle { visible: pk.chip === "underline" && c.on; anchors.bottom: parent.bottom; anchors.bottomMargin: 3; width: parent.width - 12; x: 6; height: 2; color: Sk.c("accent") }
        Text {
          id: word
          anchors.centerIn: parent
          text: pk.chip === "bracket" ? (c.on ? "[" + pk.lbl(c.modelData) + "]" : " " + pk.lbl(c.modelData) + " ") : Sk.cap(pk.lbl(c.modelData))
          color: c.on ? (pk.chip === "fill" ? Sk.c("onAccent", Sk.ink(Sk.c("accent"))) : pk.chip === "invert" ? Sk.c("bg") : Sk.c("accent")) : cm.containsMouse ? Sk.c("ink") : Sk.c("dim")
          font.family: Sk.s("font", "monospace"); font.pixelSize: Sk.n("size", 12) - 1; font.letterSpacing: Sk.n("spacing", 0)
        }
        SkHit {
          id: cm
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          kbdRadius: Sk.n("radius", 4)
          onHit: pk.chose(pk.val(c.modelData))
        }
      }
    }
  }
}

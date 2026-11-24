import QtQuick

// Ползунок строкой: подпись, шкала, число. С клавиатуры: ←/→ (h / l) — шаг, ↑/↓ — к соседним строкам (KeyNav).
// Вид — Sk.t.slider: bar (толстая скруглённая дорожка Rumda), blocks (██████▒▒▒ терминала yami), dots (точечная
// шкала DOT-MATRIX / Glyph), line (тонкая линия с квадратной ручкой), cells (клетки с контуром Bruteon).
Item {
  id: kn
  property string key
  property string label
  property string unit
  property real from: 0
  property real to: 1
  property real step: 1
  property real fallback: from
  readonly property real v: StoreShared.values[key] ?? fallback
  readonly property int digits: (String(step).split(".")[1] ?? "").length
  readonly property real frac: Math.max(0, Math.min(1, (v - from) / ((to - from) || 1)))
  readonly property string kind: Sk.s("slider", "line")
  readonly property string readout: v.toFixed(digits) + unit
  readonly property string rowLabel: label
  readonly property string rowValue: readout
  readonly property string rowHint: "← → — step · drag · right click — default"
  readonly property real labelW: Sk.n("labelW", 150)
  width: 320
  implicitHeight: Math.max(24, Sk.n("rowH", 26))
  function setTo(x) {
    const raw = from + Math.max(0, Math.min(1, x)) * (to - from)
    StoreShared.set(key, Number((Math.round(raw / step) * step).toFixed(digits)))
  }
  function nudge(d) { StoreShared.set(key, Number(Math.max(from, Math.min(to, v + d * step)).toFixed(digits))) }

  SkLabel { width: kn.labelW - 8; height: parent.height; text: kn.label; faint: !ma.containsMouse }

  Item {
    id: track
    x: kn.labelW
    width: kn.width - kn.labelW - num.width - 10
    height: parent.height

    // bar
    Rectangle {
      visible: kn.kind === "bar"
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width; height: 12; radius: 6
      color: Sk.alpha(Sk.c("ink"), 0.12)
      Rectangle { width: Math.max(height, parent.width * kn.frac); height: parent.height; radius: 6; color: Sk.c("accent") }
    }
    // line
    Item {
      visible: kn.kind === "line"
      anchors.fill: parent
      Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 2; color: Sk.alpha(Sk.c("ink"), 0.2) }
      Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * kn.frac; height: 2; color: Sk.c("accent") }
      Rectangle { anchors.verticalCenter: parent.verticalCenter; x: parent.width * kn.frac - 5; width: 10; height: 10; radius: Sk.n("knobRadius", 0); color: Sk.c("accent"); border.width: 1; border.color: Sk.c("bg") }
    }
    // cells: клетки с контуром
    Row {
      visible: kn.kind === "cells"
      anchors.verticalCenter: parent.verticalCenter
      spacing: 3
      Repeater {
        model: 12
        Rectangle {
          required property int index
          width: (track.width - 33) / 12; height: 14
          radius: 2
          color: index < Math.round(kn.frac * 12) ? Sk.c("accent") : Sk.c("card")
          border.width: 2; border.color: Sk.c("ink")
        }
      }
    }
    // dots: точечная шкала
    Row {
      visible: kn.kind === "dots"
      anchors.verticalCenter: parent.verticalCenter
      spacing: 0
      readonly property int count: Math.max(8, Math.floor(track.width / 9))
      Repeater {
        model: parent.count
        Item {
          required property int index
          width: 9; height: 9
          Rectangle {
            anchors.centerIn: parent
            readonly property bool lit: index < Math.round(kn.frac * parent.parent.count)
            width: lit ? 6 : 4; height: width; radius: width / 2
            color: lit ? (index === Math.round(kn.frac * parent.parent.count) - 1 ? Sk.c("signal", Sk.c("accent")) : Sk.c("ink")) : Sk.c("unlit", Sk.alpha(Sk.c("ink"), 0.2))
          }
        }
      }
    }
    // blocks: текстом
    Text {
      visible: kn.kind === "blocks"
      anchors.verticalCenter: parent.verticalCenter
      readonly property int count: Math.max(6, Math.floor(track.width / (Sk.n("size", 12) * 0.62)))
      readonly property int lit: Math.round(kn.frac * count)
      text: "█".repeat(lit) + "▒".repeat(count - lit)
      color: Sk.c("accent")
      font.family: Sk.s("font", "monospace"); font.pixelSize: Sk.n("size", 12)
    }
  }
  Text {
    id: num
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: 52
    horizontalAlignment: Text.AlignRight
    text: kn.readout
    color: Sk.c("ink")
    font.family: Sk.s("font", "monospace"); font.pixelSize: Sk.n("size", 12) - 1
  }
  MouseArea {
    id: ma
    x: track.x - 4; width: track.width + 8; height: parent.height
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    property real kbdRadius: Sk.n("radius", 4)
    function kbdAdjust(d) { kn.nudge(d) }
    function kbdPress() {}
    onPressed: m => kn.setTo((m.x - 4) / track.width)
    onPositionChanged: m => { if (pressed) kn.setTo((m.x - 4) / track.width) }
    onWheel: w => kn.nudge(w.angleDelta.y > 0 ? 1 : -1)
  }
}

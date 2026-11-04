import QtQuick
import "." as N

// 24-segment discrete LED slider with drag and mouse-wheel control. Outside DOT-MATRIX / Retro
// (N.Finish.segmented) — a continuous bar with a round knob in the style's shape.
Item {
  id: root

  property real value: 0
  property int segments: 24
  property color litColor: N.Finish.on
  property bool muted: false

  signal moved(real value)

  implicitHeight: 14
  implicitWidth: 220

  readonly property real segWidth: Math.max(2, (width - (segments - 1) * N.Finish.segGap) / Math.max(1, segments))
  readonly property int lit: Math.round(Math.max(0, Math.min(1, value)) * segments)

  // Сплошная полоса (не DOT-MATRIX / Retro).
  Rectangle {
    visible: !N.Finish.segmented
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width
    height: 6
    radius: N.Finish.look === "flat" || N.Finish.look === "brutal" ? 0 : 3
    color: N.Palette.surfaceHi
    border.width: N.Finish.look === "brutal" ? 1 : 0
    border.color: N.Palette.fg
    Rectangle {
      width: parent.width * Math.max(0, Math.min(1, root.value))
      height: parent.height
      radius: parent.radius
      color: root.muted ? N.Palette.muted : root.litColor
    }
    Rectangle {
      x: Math.max(0, Math.min(parent.width - width, parent.width * root.value - width / 2))
      anchors.verticalCenter: parent.verticalCenter
      width: 14
      height: 14
      radius: N.Finish.round(14)
      color: root.muted ? N.Palette.muted : root.litColor
      border.width: N.Finish.look === "brutal" ? 2 : 0
      border.color: N.Palette.fg
    }
  }

  Repeater {
    model: N.Finish.segmented ? root.segments : 0

    Rectangle {
      required property int index

      x: index * (root.segWidth + N.Finish.segGap)
      width: root.segWidth
      height: root.height
      radius: N.Finish.segRadius
      color: index < root.lit ? (root.muted ? N.Palette.muted : root.litColor) : N.Palette.surfaceHi

      Behavior on color { ColorAnimation { duration: 110 } }
    }
  }

  function emitAt(px) {
    if (width <= 0) return
    root.moved(Math.max(0, Math.min(1, px / width)))
  }

  MouseArea {
    anchors.fill: parent
    anchors.margins: -6
    cursorShape: Qt.PointingHandCursor
    onPressed: function(mouse) { root.emitAt(mouse.x - 6) }
    onPositionChanged: function(mouse) { if (pressed) root.emitAt(mouse.x - 6) }
    onWheel: function(wheel) {
      root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
  }
}

import QtQuick
import "." as N

// 24-segment discrete LED slider with drag and mouse-wheel control.
Item {
  id: root

  property real value: 0
  property int segments: 24
  property color litColor: N.Palette.lit
  property bool muted: false

  signal moved(real value)

  implicitHeight: 14
  implicitWidth: 220

  readonly property real segWidth: Math.max(2, (width - (segments - 1) * 3) / Math.max(1, segments))
  readonly property int lit: Math.round(Math.max(0, Math.min(1, value)) * segments)

  Repeater {
    model: root.segments

    Rectangle {
      required property int index

      x: index * (root.segWidth + 3)
      width: root.segWidth
      height: root.height
      radius: 3
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

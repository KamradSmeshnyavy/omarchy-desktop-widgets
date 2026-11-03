import QtQuick
import "." as N

// Round icon button with a hairline border.
Rectangle {
  id: root

  property string glyph: ""
  property int size: 36
  property bool danger: false
  property bool filled: false

  signal clicked()

  implicitWidth: size
  implicitHeight: size
  radius: size / 2
  color: filled ? (danger ? N.Palette.danger : N.Palette.lit) : (area.containsMouse ? N.Palette.surfaceHi : "transparent")
  border.width: filled ? 0 : 1
  border.color: danger ? N.Palette.danger : N.Palette.line

  Behavior on color { ColorAnimation { duration: 130 } }

  Ico {
    anchors.centerIn: parent
    glyph: root.glyph
    font.pixelSize: Math.round(root.size * 0.45)
    color: root.filled
      ? (root.danger ? N.Palette.onSignal : N.Palette.bg)
      : (root.danger ? N.Palette.danger : (area.containsMouse ? N.Palette.fg : N.Palette.dim))
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}

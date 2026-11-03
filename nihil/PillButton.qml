import QtQuick
import "." as N

// Hairline pill button with uppercase Space Mono label.
Rectangle {
  id: root

  property string text: ""
  property bool accent: false

  signal clicked()

  implicitWidth: label.implicitWidth + 24
  implicitHeight: 26
  radius: height / 2
  color: accent ? N.Palette.lit : (area.containsMouse ? N.Palette.surfaceHi : "transparent")
  border.width: accent ? 0 : 1
  border.color: N.Palette.line

  Label {
    id: label
    anchors.centerIn: parent
    text: root.text
    color: root.accent ? N.Palette.bg : (area.containsMouse ? N.Palette.fg : N.Palette.dim)
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}

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
  radius: N.Finish.round(height)
  color: accent ? N.Finish.on : (area.containsMouse ? N.Palette.surfaceHi : "transparent")
  border.width: accent ? 0 : Math.max(1, N.Finish.borderWidth)
  border.color: N.Palette.line

  Label {
    id: label
    anchors.centerIn: parent
    text: root.text
    color: root.accent ? N.Finish.onInk : (area.containsMouse ? N.Palette.fg : N.Palette.dim)
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}

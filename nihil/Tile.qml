import QtQuick
import "." as N

// Circular quick toggle tile: active = ink disc with a background glyph (inverted LED).
Item {
  id: root

  property string glyph: ""
  property string label: ""
  property bool active: false
  property bool expandable: false
  property bool expanded: false

  signal toggled()
  signal expand()

  implicitWidth: 96
  implicitHeight: 88

  Rectangle {
    id: disc
    anchors.horizontalCenter: parent.horizontalCenter
    width: 54
    height: 54
    radius: 27
    color: root.active ? N.Palette.lit : (area.containsMouse ? N.Palette.surfaceHi : N.Palette.surface)
    border.width: root.active ? 0 : 1
    border.color: N.Palette.line

    Behavior on color { ColorAnimation { duration: 170 } }

    Ico {
      anchors.centerIn: parent
      glyph: root.glyph
      font.pixelSize: 21
      color: root.active ? N.Palette.bg : N.Palette.dim
    }

    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton && root.expandable) root.expand()
        else root.toggled()
      }
    }
  }

  Row {
    anchors.top: disc.bottom
    anchors.topMargin: 8
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: 3

    Label {
      text: root.label
      color: root.active ? N.Palette.dim : N.Palette.muted

      MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        enabled: root.expandable
        cursorShape: root.expandable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.expand()
      }
    }

    Ico {
      visible: root.expandable
      glyph: String.fromCodePoint(0xF0142)
      font.pixelSize: 11
      color: root.expanded ? N.Palette.fg : N.Palette.muted
      rotation: root.expanded ? 90 : 0

      Behavior on rotation { NumberAnimation { duration: 170 } }

      MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: root.expand()
      }
    }
  }
}

import QtQuick
import "." as N

// 270-degree LED arc instrument dial with Doto value and uppercase Space Mono label.
Item {
  id: root

  property real value: 0
  property string text: ""
  property string label: ""
  property int dots: 28
  property bool alert: false

  implicitWidth: 84
  implicitHeight: 84

  readonly property real radius: Math.min(width, height) / 2 - 4
  readonly property int lit: Math.round(Math.max(0, Math.min(1, value)) * dots)

  Repeater {
    model: root.dots

    Rectangle {
      required property int index

      readonly property real angle: (135 + index * 270 / Math.max(1, root.dots - 1)) * Math.PI / 180

      width: 4
      height: 4
      radius: 2
      x: root.width / 2 + root.radius * Math.cos(angle) - 2
      y: root.height / 2 + root.radius * Math.sin(angle) - 2
      color: index < root.lit ? (root.alert ? N.Palette.danger : N.Palette.lit) : N.Palette.unlit

      Behavior on color { ColorAnimation { duration: 180 } }
    }
  }

  DotText {
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -3
    text: root.text
    font.pixelSize: 20
    color: root.alert ? N.Palette.danger : N.Palette.fg
  }

  Label {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 1
    text: root.label
    color: root.alert ? N.Palette.danger : N.Palette.muted
  }
}

import QtQuick

// Кнопка Retro CRT (его Retro/common/Button.qml): рамка акцентом, при наведении или primary — залита акцентом.
Rectangle {
  id: b
  property var pal
  property string label
  property bool primary: false
  signal pressed()
  width: caption.implicitWidth + 20
  height: 22
  color: area.containsMouse || b.primary ? pal.accent : "transparent"
  border.width: 1
  border.color: pal.accent
  CrtType { id: caption; anchors.centerIn: parent; pal: b.pal; text: b.label; color: area.containsMouse || b.primary ? b.pal.bg : b.pal.fg }
  MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.pressed() }
}

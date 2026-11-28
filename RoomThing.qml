import QtQuick

// Предмет комнаты на дашборде Cozy Room (DashRoom.qml): спрайт темы, увеличенный без сглаживания в k раз, в клетке
// cell × (x, y) комнаты; caption — подпись для записки внизу (KeyNav читает её у MouseArea); hovered(caption) — мышь
// на предмете; hit — клик или Enter.
Item {
  id: th
  required property QtObject pal
  property string sprite
  property var at: [0, 0]
  property real cell: 4
  property real k: 8
  property string caption
  signal hit()
  signal hovered(string caption)
  x: at[0] * cell; y: at[1] * cell
  width: img.width; height: img.height
  Image { id: img; source: th.pal.sprite(th.sprite); smooth: false; width: sourceSize.width * th.k; height: sourceSize.height * th.k }
  MouseArea {
    anchors.fill: parent; anchors.margins: -th.cell * 2
    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
    readonly property string caption: th.caption
    onContainsMouseChanged: if (containsMouse) th.hovered(th.caption)
    onClicked: th.hit()
  }
}

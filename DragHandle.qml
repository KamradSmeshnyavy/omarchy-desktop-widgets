import QtQuick

// Режим правки виджетов (IPC widgets toggleEdit): рамка поверх виджета `target`, перетаскивание
// с привязкой к сетке и меню по ПКМ. Пока тащим, слой берёт позицию из layer.dragKey / dragPt
// (DesktopLayer.place), на отпускании виджет становится свободным: <name>Anchor = "free",
// <name>Pos = { cx, cy, screen } — центр в долях экрана, так раскладка переживает смену разрешения.
Item {
  id: handle

  required property var host          // Widgets.qml
  required property var desk          // DesktopLayer
  required property Item target
  required property string name       // ключ виджета: clock media sysinfo network todo quote photo
  property int pad: 0

  readonly property string anchorKey: name + "Anchor"
  readonly property bool free: String(host.value(anchorKey)) === "free"
  readonly property bool floating: host.flag(name + "Float")

  visible: host.editMode && target && target.visible
  x: target ? target.x - pad : 0
  y: target ? target.y - pad : 0
  width: target ? target.width + 2 * pad : 0
  height: target ? target.height + 2 * pad : 0
  z: 50

  // Пунктирная рамка: четыре полосы из штрихов (Canvas дороже, а штрихи статичны).
  Repeater {
    model: 4
    delegate: Item {
      required property int index
      readonly property bool horizontal: index < 2
      x: index === 3 ? handle.width - 2 : 0
      y: index === 1 ? handle.height - 2 : 0
      width: horizontal ? handle.width : 2
      height: horizontal ? 2 : handle.height
      clip: true
      Row {
        visible: parent.horizontal
        spacing: 6
        Repeater { model: Math.ceil(handle.width / 14); Rectangle { width: 8; height: 2; color: handle.host.accent } }
      }
      Column {
        visible: !parent.horizontal
        spacing: 6
        Repeater { model: Math.ceil(handle.height / 14); Rectangle { width: 2; height: 8; color: handle.host.accent } }
      }
    }
  }
  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(handle.host.accent.r, handle.host.accent.g, handle.host.accent.b, mouse.pressed ? 0.16 : mouse.containsMouse ? 0.10 : 0.05)
    radius: 6
  }

  // Ярлык: имя и состояние (свободный / поверх окон).
  Rectangle {
    x: 6
    y: -height - 6 < -handle.y ? 6 : -height - 6
    height: tag.implicitHeight + 8
    width: tag.implicitWidth + 14
    radius: height / 2
    color: handle.host.accent
    Text {
      id: tag
      anchors.centerIn: parent
      text: handle.desk.label(handle.name) + (handle.floating ? "  󰐃" : handle.free ? "  󰆾" : "")
      font.family: handle.host.fontFamily
      font.pixelSize: 12
      font.bold: true
      color: handle.host.background
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
    property point grab: Qt.point(0, 0)

    onPressed: e => {
      if (e.button === Qt.RightButton) {
        handle.desk.openMenu(handle.name, handle.x + e.x, handle.y + e.y)
        return
      }
      handle.desk.closeMenu()
      grab = Qt.point(e.x - handle.pad, e.y - handle.pad)
      handle.desk.dragKey = handle.anchorKey
      handle.desk.dragPt = Qt.point(handle.target.x, handle.target.y)
    }
    onPositionChanged: e => {
      if (!pressed || handle.desk.dragKey !== handle.anchorKey) return
      var p = mapToItem(handle.desk.contentItem, e.x, e.y)
      handle.desk.dragPt = handle.desk.snap(p.x - grab.x, p.y - grab.y, handle.target)
    }
    onReleased: e => {
      if (e.button !== Qt.LeftButton || handle.desk.dragKey !== handle.anchorKey) return
      var pt = handle.desk.dragPt
      handle.host.placeFree(handle.name, handle.desk.screenName,
                            (pt.x + handle.target.width / 2) / handle.desk.width,
                            (pt.y + handle.target.height / 2) / handle.desk.height)
      handle.desk.dragKey = ""
    }
  }
}

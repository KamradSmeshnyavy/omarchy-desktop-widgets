import QtQuick

// Перенос без режима правки (как карточки и Desk у Vitreus, код свой): виджет берут за любое место и тянут — кнопки
// внутри работают как прежде (DragHandler берёт виджет, только когда курсор ушёл дальше порога). Углы — размер
// (курсор подсказывает; <name>Scale 0.6…1.8, тянут от противоположного угла), булавка при наведении — вернуть на место,
// отпустил рядом с его местом — сам прилипает обратно. Пока тянут — слой берёт позицию из desk.dragKey / dragPt.
Item {
  id: g

  required property var host          // Widgets.qml
  required property var desk          // DesktopLayer
  required property Item target
  required property string name
  property int pad: 0

  readonly property string anchorKey: name + "Anchor"
  readonly property bool free: String(host.value(anchorKey)) === "free"
  readonly property real s: desk.scaleOf(name)
  // видимые границы (виджет масштабируется от центра)
  readonly property rect b: target ? Qt.rect(target.x + target.width * (1 - s) / 2 - pad, target.y + target.height * (1 - s) / 2 - pad,
                                             target.width * s + 2 * pad, target.height * s + 2 * pad) : Qt.rect(0, 0, 0, 0)

  visible: !host.editMode && target && target.visible && host.value("directMove") !== false
  x: b.x; y: b.y; width: b.width; height: b.height
  z: 40

  // где виджет стоял бы на своём якоре — туда он прилипает
  function dockPoint() {
    var a = String(host.value(name + "AnchorDocked") || "")
    return a ? desk.placeAt(target, anchorKey, a) : null
  }

  // ── перенос ──
  property point grab: Qt.point(0, 0)
  property bool near: false
  DragHandler {
    id: drag
    target: null
    dragThreshold: 8
    onActiveChanged: {
      if (active) {
        var p = g.mapToItem(g.desk.contentItem, centroid.pressPosition.x, centroid.pressPosition.y)
        g.grab = Qt.point(p.x - g.target.x, p.y - g.target.y)
        g.desk.dragPt = Qt.point(g.target.x, g.target.y)
        g.desk.dragKey = g.anchorKey
      } else if (g.desk.dragKey === g.anchorKey) {
        var pt = g.desk.dragPt
        if (g.near) g.host.dock(g.name)
        else g.host.placeFree(g.name, g.desk.screenName, (pt.x + g.target.width / 2) / g.desk.width, (pt.y + g.target.height / 2) / g.desk.height)
        g.desk.dragKey = ""
        g.near = false
      }
    }
    onCentroidChanged: {
      if (!active) return
      var p = g.mapToItem(g.desk.contentItem, centroid.position.x, centroid.position.y)
      var pt = g.desk.snap(p.x - g.grab.x, p.y - g.grab.y, g.target)
      var d = g.dockPoint()
      g.near = !!d && Math.hypot(pt.x - d.x, pt.y - d.y) < 56
      g.desk.dragPt = g.near ? d : pt
    }
  }
  HoverHandler { id: hov; cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor }

  // подсветка «прилипнет на место»
  Rectangle {
    anchors.fill: parent
    radius: 16
    color: "transparent"
    border.width: 2
    border.color: g.host.accent
    opacity: g.near ? 0.9 : drag.active ? 0.35 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }
  }

  // ── размер: углы ──
  property real s0: 1
  property real d0: 1
  Repeater {
    model: 4
    Item {
      id: corner
      required property int index
      readonly property bool onRight: index === 1 || index === 3
      readonly property bool onBottom: index >= 2
      x: onRight ? g.width - 18 : 0
      y: onBottom ? g.height - 18 : 0
      width: 18; height: 18
      MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        preventStealing: true
        cursorShape: corner.onRight === corner.onBottom ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
        function center() { return g.mapToItem(g.desk.contentItem, g.width / 2, g.height / 2) }
        onPressed: function(e) {
          g.s0 = g.s
          var c = center(), p = mapToItem(g.desk.contentItem, e.x, e.y)
          g.d0 = Math.max(10, Math.hypot(p.x - c.x, p.y - c.y))
          g.desk.liveScale = g.s0
          g.desk.scaleKey = g.name
        }
        onPositionChanged: function(e) {
          if (!pressed) return
          var c = center(), p = mapToItem(g.desk.contentItem, e.x, e.y)
          g.desk.liveScale = Math.max(0.6, Math.min(1.8, g.s0 * Math.hypot(p.x - c.x, p.y - c.y) / g.d0))
        }
        onReleased: {
          var o = {}
          o[g.name + "Scale"] = Math.round(g.desk.liveScale * 100) / 100
          if (!g.free) {
            var fk = g.host.freeKeys(g.name, g.desk.screenName, (g.target.x + g.target.width / 2) / g.desk.width, (g.target.y + g.target.height / 2) / g.desk.height)
            for (var k in fk) o[k] = fk[k]
          }
          g.host.saveKeys(o)
          g.desk.scaleKey = ""
        }
      }
    }
  }

  // ── булавка: вернуть на место ──
  Rectangle {
    visible: g.free
    anchors { top: parent.top; right: parent.right; margins: 6 }
    width: 26; height: 26; radius: 13
    opacity: hov.hovered && !drag.active ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }
    color: pin.containsMouse ? g.host.accent : Qt.rgba(g.host.background.r, g.host.background.g, g.host.background.b, 0.85)
    border.width: 1
    border.color: Qt.rgba(g.host.foreground.r, g.host.foreground.g, g.host.foreground.b, 0.25)
    Text {
      anchors.centerIn: parent
      text: "󰐄"
      font.family: g.host.iconFamily
      font.pixelSize: 13
      color: pin.containsMouse ? g.host.background : g.host.foreground
    }
    MouseArea { id: pin; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: g.host.dock(g.name) }
  }
}

import QtQuick

// «Включение трубки» Retro CRT (его Retro/common/Tube.qml): при t 0 → 0.25 по центру растёт яркая черта во всю
// ширину, дальше содержимое раскрывается по вертикали из этой черты, черта гаснет.
Item {
  id: tube
  property var pal
  property real t: 0
  default property alias content: inner.data
  readonly property real ys: Math.max(0.006, Math.min(1, (t - 0.25) / 0.75))
  readonly property real xs: Math.min(1, t * 4)
  Item {
    id: inner
    anchors.fill: parent
    opacity: tube.t > 0.25 ? 1 : 0
    transform: Scale { origin.x: tube.width / 2; origin.y: tube.height / 2; yScale: tube.ys }
  }
  Rectangle {
    visible: tube.t < 0.999
    anchors.centerIn: parent
    width: parent.width * tube.xs
    height: Math.max(2, parent.height * tube.ys)
    color: tube.pal.accent
    opacity: Math.max(0, 1 - tube.ys) * 0.9
  }
}

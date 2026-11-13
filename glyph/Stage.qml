import QtQuick

// Из glyph-rice (components/Stage.qml, GPL-3.0). Холст в пикселях макета 1920×1080: растянут на родителя, внутри всё
// меряется как в макете. s — масштаб (логических пикселей на пиксель макета).
Item {
  readonly property real s: Math.min(parent.width / 1920, parent.height / 1080)
  width: parent.width / s
  height: parent.height / s
  scale: s
  transformOrigin: Item.TopLeft
}

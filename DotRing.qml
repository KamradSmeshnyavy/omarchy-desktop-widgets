import QtQuick

// Кольцо из n точек по краю элемента, горит долей f (домашний экран glyph, Deck).
Item {
  id: ring
  property real f: 0
  property int n: 44
  property real dot: 6
  property real inset: 18
  property color on: "#ffffff"
  property color off: "#333333"
  Repeater {
    model: ring.n
    Rectangle {
      required property int index
      readonly property real a: -Math.PI / 2 + index / ring.n * 2 * Math.PI
      width: ring.dot; height: ring.dot; radius: ring.dot / 2
      x: ring.width / 2 + Math.cos(a) * (ring.width / 2 - ring.inset) - ring.dot / 2
      y: ring.height / 2 + Math.sin(a) * (ring.height / 2 - ring.inset) - ring.dot / 2
      color: index < Math.round(Math.max(0, Math.min(1, ring.f)) * ring.n) ? ring.on : ring.off
    }
  }
}

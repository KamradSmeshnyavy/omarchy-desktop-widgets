import QtQuick

// Полоса из n точек, горит долей f (домашний экран glyph, Deck).
Row {
  id: seg
  property real f: 0
  property int n: 24
  property real dot: 6
  property color on: "#ffffff"
  property color off: "#333333"
  spacing: (width - n * dot) / Math.max(1, n - 1)
  Repeater {
    model: seg.n
    Rectangle {
      required property int index
      width: seg.dot; height: seg.dot; radius: seg.dot / 2
      color: index < Math.round(Math.max(0, Math.min(1, seg.f)) * seg.n) ? seg.on : seg.off
    }
  }
}

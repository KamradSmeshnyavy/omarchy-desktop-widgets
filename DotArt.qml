import QtQuick
import QtQuick.Effects

// Обложка точками (домашний экран glyph, Deck): серая картинка сквозь маску из точек в круге,
// крутится, пока spinning. Нет обложки — пустой круг цвета off.
Item {
  id: da
  property string url: ""
  property bool spinning: false
  property real step: 6
  property color off: "#333333"
  property real turn: 0
  Timer { running: da.spinning && da.visible; interval: 33; repeat: true; onTriggered: da.turn = (da.turn + 0.86) % 360 }
  Image {
    id: cover
    anchors.fill: parent
    source: da.url
    fillMode: Image.PreserveAspectCrop
    visible: false
    asynchronous: true
    sourceSize: Qt.size(Math.max(1, da.width), Math.max(1, da.height))
  }
  Canvas {
    id: dotMask
    anchors.fill: parent
    visible: false
    layer.enabled: true
    onWidthChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.fillStyle = "white"
      var st = da.step, r0 = width / 2
      for (var y = st / 2; y < height; y += st)
        for (var x = st / 2; x < width; x += st) {
          var dx = x - r0, dy = y - r0
          if (dx * dx + dy * dy > (r0 - 2) * (r0 - 2)) continue
          ctx.beginPath(); ctx.arc(x, y, st * 0.37, 0, 2 * Math.PI); ctx.fill()
        }
    }
  }
  MultiEffect {
    anchors.fill: parent
    visible: cover.status === Image.Ready
    source: cover
    rotation: da.turn
    saturation: -1
    brightness: 0.15
    contrast: 0.4
    maskEnabled: true
    maskSource: dotMask
    maskThresholdMin: 0.5
    maskSpreadAtMin: 0.3
  }
  Rectangle {
    visible: cover.status !== Image.Ready
    anchors.fill: parent
    radius: width / 2
    color: "transparent"
    border.width: 1
    border.color: da.off
  }
}

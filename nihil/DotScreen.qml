import QtQuick
import QtQuick.Effects
import "." as N

// Grayscale image viewed through a round LED-matrix aperture mask.
Item {
  id: root

  property string source: ""
  property int pitch: 4
  property int radius: 14

  clip: true

  Rectangle {
    anchors.fill: parent
    radius: root.radius
    color: N.Palette.surface
    border.width: 1
    border.color: N.Palette.lineSoft

    Text {
      anchors.centerIn: parent
      visible: art.status !== Image.Ready
      text: String.fromCodePoint(0xF0386)
      font.family: N.Palette.fontIcon
      font.pixelSize: 28
      color: N.Palette.line
    }
  }

  Image {
    id: art
    anchors.fill: parent
    source: root.source
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    visible: false
    sourceSize.width: Math.max(64, root.width * 2)
    sourceSize.height: Math.max(64, root.height * 2)
  }

  MultiEffect {
    anchors.fill: parent
    source: art
    visible: art.status === Image.Ready
    saturation: -1
    contrast: 0.28
    brightness: 0.05
    maskEnabled: true
    maskSource: mask
  }

  Canvas {
    id: mask
    anchors.fill: parent
    visible: false
    layer.enabled: true

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.fillStyle = "white"
      var p = Math.max(2, root.pitch)
      for (var y = p / 2; y < height; y += p) {
        for (var x = p / 2; x < width; x += p) {
          ctx.beginPath()
          ctx.arc(x, y, p * 0.42, 0, 2 * Math.PI)
          ctx.fill()
        }
      }
    }
  }
}

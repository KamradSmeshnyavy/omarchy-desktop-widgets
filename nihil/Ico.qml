import QtQuick
import "." as N

// Centered Nerd Font glyph box so icons sit visually centered inside circles.
Item {
  id: root

  property string glyph: ""
  property alias color: label.color
  property alias font: label.font

  implicitWidth: Math.max(16, ink.advanceWidth)
  implicitHeight: Math.max(16, line.height)

  TextMetrics {
    id: ink
    font: label.font
    text: root.glyph
  }

  FontMetrics {
    id: line
    font: label.font
  }

  Text {
    id: label
    x: root.width / 2 - (ink.tightBoundingRect.x + ink.tightBoundingRect.width / 2)
    y: root.height / 2 - (line.ascent + ink.tightBoundingRect.y + ink.tightBoundingRect.height / 2)
    text: root.glyph
    color: N.Palette.dim
    font.family: N.Palette.fontIcon
    font.pixelSize: 16

    Behavior on color { ColorAnimation { duration: 130 } }
  }
}

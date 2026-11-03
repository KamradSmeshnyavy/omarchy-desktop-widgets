import QtQuick
import "." as N

// Dot-matrix display voice (Doto Bold).
Text {
  color: N.Palette.fg
  font.family: N.Palette.fontDot
  font.pixelSize: 28
  font.weight: Font.Bold
  verticalAlignment: Text.AlignVCenter
}

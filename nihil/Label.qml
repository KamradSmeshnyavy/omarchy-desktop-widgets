import QtQuick
import "." as N

// Metadata voice: uppercase Space Mono with wide tracking.
Text {
  color: N.Palette.muted
  font.family: N.Palette.fontMono
  font.pixelSize: 10
  font.letterSpacing: 1.6
  font.capitalization: Font.AllUppercase
  elide: Text.ElideRight
  verticalAlignment: Text.AlignVCenter
}

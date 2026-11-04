import QtQuick
import "." as N

// Metadata voice: uppercase Space Mono with wide tracking (font and case — N.Finish).
Text {
  color: N.Palette.muted
  font.family: N.Finish.labelFont
  font.pixelSize: N.Finish.labelSize
  font.letterSpacing: N.Finish.tracking
  font.weight: N.Finish.labelWeight
  font.capitalization: N.Finish.upper ? Font.AllUppercase : Font.MixedCase
  elide: Text.ElideRight
  verticalAlignment: Text.AlignVCenter
}

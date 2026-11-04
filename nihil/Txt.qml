import QtQuick
import "." as N

// Interface voice (Space Grotesk; outside Nihil — N.Finish.textFont).
Text {
  color: N.Palette.fg
  font.family: N.Finish.textFont
  font.pixelSize: 14
  elide: Text.ElideRight
  verticalAlignment: Text.AlignVCenter
}

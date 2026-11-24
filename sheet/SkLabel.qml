import QtQuick

// Подпись в шрифте облика (Sk.t: font, size, caps, spacing, ink / dim)
Text {
  property bool head: false
  property bool lit: false
  property bool faint: true
  color: lit ? Sk.c("accent") : faint ? Sk.c("dim") : Sk.c("ink")
  font.family: head ? Sk.s("head", Sk.s("font", "monospace")) : Sk.s("font", "monospace")
  font.pixelSize: Sk.n("size", 12)
  font.letterSpacing: Sk.n("spacing", 0)
  font.capitalization: Sk.n("caps", false) ? Font.AllUppercase : Font.MixedCase
  verticalAlignment: Text.AlignVCenter
  elide: Text.ElideRight
  textFormat: Text.PlainText
}

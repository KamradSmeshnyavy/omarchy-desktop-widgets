import QtQuick

// «Расшифровка» текста HUD Space (elifouts/Dotfiles, GPL-3.0 — его common/DecodeText.qml и decode.js): при появлении и
// смене строка проступает слева направо через шум «#$%&*+=<>/\|01». Капсом вразрядку (1.6), 11 px.
// Тикающее (часы, проценты) — decode: false. Копия — kamradsmeshnyavy.bar/modules/SpaceDecode.qml (правку переносить в обе).
Item {
  id: hud
  property string text
  property alias color: label.color
  property alias font: label.font
  property string family: "JetBrainsMono Nerd Font"
  property int size: 11
  property bool decode: true
  property bool caps: true
  property alias horizontalAlignment: label.horizontalAlignment

  implicitWidth: Math.ceil(tm.advanceWidth)
  implicitHeight: label.implicitHeight
  TextMetrics { id: tm; font: label.font; text: hud.text }

  readonly property string noise: "#$%&*+=<>/\\|01"
  function frame(from, to, k) {
    if (k >= 1) return to
    var n = Math.max(from.length, to.length), lead = k * (n + 5), out = ""
    for (var i = 0; i < n; i++) {
      var t = to[i] || "", f = from[i] || ""
      if (i < lead - 5 || t === f) out += i < lead ? t : f
      else if (i < lead) out += /\s/.test(t || f) ? (t || f) : noise[Math.floor(Math.random() * noise.length)]
      else out += f
    }
    return out.replace(/\s+$/, "")
  }
  function dur(len, first) { return first ? 180 + Math.min(len, 30) * 9 : 120 + Math.min(len, 30) * 6 }

  property string from: ""
  property string was: ""
  property real k: 1
  property bool fresh: true
  function run() {
    if (!decode) { from = was = text; k = 1; return }
    if (!visible) { fresh = true; return }
    from = k < 1 ? frame(from, was, k) : was
    was = text
    morph.duration = dur(text.length, fresh || from === "")
    k = 0
    morph.restart()
    fresh = false
  }
  onTextChanged: run()
  onDecodeChanged: run()
  onVisibleChanged: if (visible && fresh) run()
  Component.onCompleted: run()
  NumberAnimation { id: morph; target: hud; property: "k"; to: 1 }

  Text {
    id: label
    anchors.fill: parent
    text: hud.decode ? hud.frame(hud.from, hud.was, hud.k) : hud.text
    font.family: hud.family
    font.pixelSize: hud.size
    font.letterSpacing: hud.caps ? 1.6 : 0
    font.capitalization: hud.caps ? Font.AllUppercase : Font.MixedCase
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText
  }
}

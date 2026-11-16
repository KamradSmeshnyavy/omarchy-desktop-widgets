import QtQuick

// Содержимое раздела меню Super+M (wifi / bt / audio) с обликом, заданным снаружи: списки сетей с вводом пароля,
// устройств Bluetooth, выходов звука, ползунок громкости (←/→ с клавиатуры) и микрофон. Строка — шрифт font, высота
// rowH, скругление radius; выбранная / включённая — заливка litFill и текст litInk; наведённая — hoverFill; рамка — line.
// textOn / textOff (например «[x] » / «[ ] ») ставятся перед строками-переключателями; bar — вид ползунка: "fill" или
// "blocks" (█▒ для терминала).
Flickable {
  id: sb
  property var md: null
  property string page: ""
  property color ink: "white"
  property color dim: Qt.rgba(ink.r, ink.g, ink.b, 0.6)
  property color litFill: "white"
  property color litInk: "black"
  property color hoverFill: Qt.rgba(ink.r, ink.g, ink.b, 0.08)
  property color line: Qt.rgba(ink.r, ink.g, ink.b, 0.25)
  property color field: "transparent"
  property string font: "monospace"
  property int size: 12
  property int rowH: 38
  property real radius: 8
  property string textOn: ""
  property string textOff: ""
  property string bar: "fill"
  property string pwFor: ""
  readonly property var st: md ? md.st : null
  clip: true
  contentHeight: col.implicitHeight
  boundsBehavior: Flickable.StopAtBounds

  component Line: Item {
    id: ln
    property string text: ""
    property string tail: ""
    property bool on: false
    property bool toggle: false
    signal hit()
    width: sb.width - 4; height: sb.rowH
    Rectangle { anchors.fill: parent; radius: sb.radius; color: ln.on ? sb.litFill : lh.hovered ? sb.hoverFill : "transparent"; border.width: lh.hovered && !ln.on ? 1 : 0; border.color: sb.line }
    Text { x: 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 130; elide: Text.ElideRight; text: (ln.toggle ? (ln.on ? sb.textOn : sb.textOff) : "") + ln.text; color: ln.on ? sb.litInk : sb.ink; font.family: sb.font; font.pixelSize: sb.size }
    Text { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: ln.tail; color: ln.on ? sb.litInk : sb.dim; font.family: sb.font; font.pixelSize: sb.size - 1 }
    HoverHandler { id: lh; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: ln.hit() }
  }

  Column {
    id: col
    width: sb.width
    spacing: 4
    // Wi-Fi
    Line { visible: sb.page === "wifi"; toggle: true; text: "wi-fi"; on: !!sb.st && sb.st.wifi; tail: sb.st && sb.st.wifi ? (sb.st.ssid || "on") : "off"; onHit: sb.st.toggleWifi() }
    Repeater {
      model: sb.page === "wifi" && sb.md ? sb.md.networks : []
      Line {
        required property var modelData
        text: (modelData.secure ? "🔒 " : "   ") + modelData.ssid
        tail: modelData.active ? "connected" : "▂▄▆█".slice(0, Math.max(1, Math.ceil(modelData.signal / 25)))
        on: modelData.active
        onHit: modelData.active ? sb.md.disconnectWifi(modelData.ssid) : (modelData.secure ? sb.pwFor = modelData.ssid : sb.md.connectWifi(modelData.ssid, ""))
      }
    }
    Item {
      visible: sb.page === "wifi" && sb.pwFor !== ""
      width: sb.width - 4; height: sb.rowH
      Rectangle { anchors.fill: parent; radius: sb.radius; color: sb.field; border.width: 1; border.color: sb.ink }
      TextInput {
        x: 12; width: parent.width - 24; anchors.verticalCenter: parent.verticalCenter
        echoMode: TextInput.Password; color: sb.ink; font.family: sb.font; font.pixelSize: sb.size
        onVisibleChanged: if (visible) forceActiveFocus()
        Keys.onReturnPressed: { sb.md.connectWifi(sb.pwFor, text); text = ""; sb.pwFor = "" }
        Keys.onEscapePressed: { text = ""; sb.pwFor = "" }
        Text { visible: !parent.text.length; text: "password for " + sb.pwFor; color: sb.dim; font: parent.font }
      }
    }
    // Bluetooth
    Line { visible: sb.page === "bt"; toggle: true; text: "bluetooth"; on: !!sb.st && sb.st.bt; tail: sb.st && sb.st.bt ? "on" : "off"; onHit: sb.st.toggleBt() }
    Line { visible: sb.page === "bt"; text: "⟳ scan for devices"; onHit: sb.md.scanBt() }
    Repeater {
      model: sb.page === "bt" && sb.md ? sb.md.devices : []
      Line {
        required property var modelData
        text: modelData.name
        tail: modelData.connected ? "connected" : modelData.paired ? "paired" : "new"
        on: modelData.connected
        onHit: sb.md.toggleDevice(modelData)
      }
    }
    // Звук
    Item {
      visible: sb.page === "audio"
      width: sb.width - 4; height: sb.rowH + 22
      property bool kbdNav: sb.page === "audio"
      property real kbdRadius: sb.radius
      function kbdPress() { sb.st.setVol(sb.st.vol > 0 ? 0 : 0.5) }
      function kbdAdjust(d) { sb.st.setVol(Math.max(0, Math.min(1, sb.st.vol + d * 0.05))) }
      Text { x: 4; text: "volume " + Math.round((sb.st ? sb.st.vol : 0) * 100) + "%"; color: sb.ink; font.family: sb.font; font.pixelSize: sb.size }
      Rectangle {
        visible: sb.bar === "fill"
        y: 22; width: parent.width; height: sb.rowH - 14; radius: sb.radius; color: sb.field; border.width: 1; border.color: sb.line
        Rectangle { x: 3; y: 3; height: parent.height - 6; radius: Math.max(0, sb.radius - 3); width: Math.max(0, (parent.width - 6) * Math.min(1, sb.st ? sb.st.vol : 0)); color: sb.litFill }
      }
      Text {
        visible: sb.bar === "blocks"
        y: 22; x: 4
        readonly property int n: 32
        readonly property int lit: Math.round(Math.min(1, sb.st ? sb.st.vol : 0) * n)
        text: "[" + "█".repeat(lit) + "▒".repeat(n - lit) + "]"
        color: sb.litFill; font.family: sb.font; font.pixelSize: sb.size
      }
      MouseArea { y: 22; width: parent.width; height: sb.rowH - 14
        onPressed: function(e) { sb.st.setVol(Math.max(0, Math.min(1, e.x / width))) }
        onPositionChanged: function(e) { if (pressed) sb.st.setVol(Math.max(0, Math.min(1, e.x / width))) } }
    }
    Line { visible: sb.page === "audio"; toggle: true; text: "microphone"; on: !!sb.st && !sb.st.micMuted; tail: sb.st && sb.st.micMuted ? "muted" : "on"; onHit: sb.st.toggleMic() }
    Text { visible: sb.page === "audio"; x: 4; text: "output"; color: sb.dim; font.family: sb.font; font.pixelSize: sb.size - 1 }
    Repeater {
      model: sb.page === "audio" && sb.md ? sb.md.sinks : []
      Line {
        required property var modelData
        text: sb.md.sinkName(modelData)
        on: sb.md.defaultSink === modelData
        onHit: sb.md.setSink(modelData)
      }
    }
  }
}

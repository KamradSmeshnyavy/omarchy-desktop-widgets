import QtQuick

// Меню Super+M Vitreus — «стеклянное кольцо» (свой, в облике Vitreus: жидкое стекло — полупрозрачные капли с бликом и
// ободком, акцент темы). Вокруг часов в центре по кругу лежат капли-разделы; колесо крутит кольцо, выбранная капля
// крупнее. Нажатая капля «перетекает» в центр и разрастается в стеклянную панель раздела, кольцо уходит в дымку.
// Стрелки / Tab / Enter (KeyNav), [ / ] — повернуть кольцо, Esc — назад / закрыть.
MenuBase {
  id: m
  body: sbody
  readonly property color fg: host ? host.foreground : "white"
  readonly property color bg: host ? host.background : "black"
  readonly property color acc: host ? host.accent : "white"
  function a(c, k) { return Qt.rgba(c.r, c.g, c.b, k) }
  readonly property var drops: [["wifi", "\u{F05A9}", "page"], ["bt", "\u{F00AF}", "page"], ["audio", "\u{F057E}", "page"], ["night", "\u{F0594}", "t"], ["dnd", "\u{F009B}", "t"],
    ["awake", "\u{F0176}", "t"], ["mic", "\u{F036C}", "t"], ["shot", "\u{F019E}", "x"], ["tweak", "\u{F0493}", "x"], ["power", "\u{F0425}", "x"]]
  property real spin: 0
  Behavior on spin { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
  property real flow: page !== "" ? 1 : 0
  Behavior on flow { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
  property point from: Qt.point(0, 0)
  function keys(e) {
    if (e.key === Qt.Key_BracketRight) { spin += 36; return true }
    if (e.key === Qt.Key_BracketLeft) { spin -= 36; return true }
    return false
  }
  function on(id) { var s = m.st; if (!s) return false
    return id === "night" ? s.night : id === "dnd" ? s.dnd : id === "awake" ? s.caffeine : id === "mic" ? !s.micMuted : id === "wifi" ? s.wifi : id === "bt" ? s.bt : false }
  function act(d, x, y) {
    if (d[2] === "page") { from = Qt.point(x, y); page = d[0]; return }
    if (d[0] === "night") m.st.toggleNight(); else if (d[0] === "dnd") m.st.toggleDnd(); else if (d[0] === "awake") m.st.toggleCaffeine()
    else if (d[0] === "mic") m.st.toggleMic()
    else if (d[0] === "shot") { m.close(); m.run(["omarchy-capture-screenshot"]) }
    else if (d[0] === "tweak") { m.close(); m.run(["omarchy-shell", "shell", "toggle", "kamradsmeshnyavy.customizer"]) }
    else { m.close(); m.host.powerOpen = true }
  }

  component Glass: Rectangle {
    color: m.a(m.bg, 0.42); border.width: 1; border.color: m.a(m.fg, 0.3)
    Rectangle { x: 1; y: 1; width: parent.width - 2; height: parent.height * 0.45; radius: parent.radius
      gradient: Gradient { GradientStop { position: 0; color: m.a("#ffffff", 0.18) } GradientStop { position: 1; color: "transparent" } } }
  }

  Item {
    id: ring
    width: 520; height: 520
    anchors.centerIn: parent
    opacity: m.k * (1 - 0.8 * m.flow)
    scale: (0.9 + 0.1 * m.k) * (1 + 0.15 * m.flow)
    enabled: m.page === ""
    WheelHandler { onWheel: function(e) { m.spin += e.angleDelta.y < 0 ? 36 : -36 } }
    Glass {
      anchors.centerIn: parent; width: 190; height: 190; radius: 95
      Column { anchors.centerIn: parent; spacing: 2
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(new Date(), "HH:mm"); color: m.fg; font.pixelSize: 44; font.weight: 700 }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(new Date(), "dddd").toLowerCase(); color: m.a(m.fg, 0.7); font.pixelSize: 13 } }
    }
    Repeater {
      model: m.drops
      Glass {
        id: dr
        required property var modelData
        required property int index
        readonly property real ang: (index / m.drops.length * 360 + m.spin) * Math.PI / 180
        readonly property bool lit: m.on(modelData[0])
        width: 76; height: 76; radius: 38
        x: ring.width / 2 + Math.sin(ang) * 200 - width / 2
        y: ring.height / 2 - Math.cos(ang) * 200 - height / 2
        scale: hv.hovered ? 1.15 : 1
        Behavior on scale { NumberAnimation { duration: 160 } }
        color: lit ? m.a(m.acc, 0.6) : m.a(m.bg, 0.42)
        Column { anchors.centerIn: parent; spacing: 2
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: dr.modelData[1]; color: m.fg; font.pixelSize: 22 }
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: dr.modelData[0]; color: m.a(m.fg, 0.75); font.pixelSize: 9 } }
        HoverHandler { id: hv; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: m.act(dr.modelData, dr.x + dr.width / 2, dr.y + dr.height / 2) }
      }
    }
  }
  // панель раздела — капля перетекает в центр и разрастается
  Glass {
    id: panel
    visible: m.flow > 0.01
    width: 120 + 400 * m.flow; height: 120 + 340 * m.flow; radius: 60 - 34 * m.flow
    x: (m.width - width) / 2 + (m.from.x - ring.width / 2) * (1 - m.flow)
    y: (m.height - height) / 2 + (m.from.y - ring.height / 2) * (1 - m.flow)
    opacity: m.k
    MouseArea { anchors.fill: parent }
    Text { x: 24; y: 18; opacity: m.flow; text: ({ wifi: "\u{F05A9}  wi-fi", bt: "\u{F00AF}  bluetooth", audio: "\u{F057E}  sound" })[m.page] || ""; color: m.fg; font.pixelSize: 16; font.weight: 700 }
    SectionBody {
      id: sbody
      opacity: m.flow
      x: 20; y: 54; width: panel.width - 40; height: panel.height - 72
      md: m.md; page: m.page
      ink: m.fg; litFill: m.a(m.acc, 0.75); litInk: m.fg; radius: 14; size: 12; rowH: 40; field: m.a(m.fg, 0.06); font: "sans-serif"
    }
  }
}

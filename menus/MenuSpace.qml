import QtQuick
import QtQuick.Shapes
import ".."

// Меню Super+M Space — «бортовой компьютер» (свой, в облике стиля Space из elifouts/Dotfiles, GPL-3.0: HUD, акцент
// темы, капс вразрядку, плашки со срезанным углом, орбиты как на его звёздной карте Overview). В центре — корабль,
// вокруг по наклонной орбите летят планеты-разделы (переключатели светятся акцентом, разделы — с кольцом). Колесо /
// [ ] крутят орбиту, ближняя к зрителю планета крупнее и ярче. Нажатая планета подлетает к кораблю и разворачивается в
// плашку HUD раздела (wi-fi / bluetooth / sound), орбита гаснет. Стрелки / Tab / Enter (KeyNav), Esc — назад / закрыть.
MenuBase {
  id: m
  body: sbody
  readonly property color fg: host ? host.foreground : "white"
  readonly property color bg: host ? host.background : "black"
  readonly property color acc: host ? host.accent : "white"
  function a(c, k) { return Qt.rgba(c.r, c.g, c.b, k) }
  readonly property string mono: Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : "monospace"
  // [id, значок, вид: page — раздел, t — переключатель, x — действие]
  readonly property var planets: [["wifi", "\u{F05A9}", "page"], ["bt", "\u{F00AF}", "page"], ["audio", "\u{F057E}", "page"], ["night", "\u{F0594}", "t"],
    ["dnd", "\u{F009B}", "t"], ["awake", "\u{F0176}", "t"], ["mic", "\u{F036C}", "t"], ["shot", "\u{F019E}", "x"], ["tweak", "\u{F0493}", "x"], ["power", "\u{F0425}", "x"]]
  readonly property var names: ({ wifi: "wi-fi", bt: "bluetooth", audio: "sound", night: "night light", dnd: "do not disturb",
    awake: "stay awake", mic: "microphone", shot: "screenshot", tweak: "customizer", power: "power" })
  property real spin: 0
  Behavior on spin { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
  property real drift: 0
  NumberAnimation on drift { running: m.open && m.page === ""; from: 0; to: 360; duration: 120000; loops: Animation.Infinite }
  property real flow: page !== "" ? 1 : 0
  Behavior on flow { NumberAnimation { duration: 460; easing.type: Easing.OutCubic } }
  property point from: Qt.point(0, 0)
  property string hoverId: ""
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

  // плашка HUD: срезанный угол, рамка акцентом 35 %, черта 2 px акцентом слева
  component Plate: Item {
    id: pl
    property real cut: 14
    property real fill: 0.72
    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeWidth: 1
        strokeColor: m.a(m.acc, 0.35)
        fillColor: m.a(m.bg, pl.fill)
        startX: pl.cut; startY: 0
        PathLine { x: pl.width; y: 0 }
        PathLine { x: pl.width; y: pl.height }
        PathLine { x: 0; y: pl.height }
        PathLine { x: 0; y: pl.cut }
        PathLine { x: pl.cut; y: 0 }
      }
    }
    Rectangle { x: 0; y: pl.cut; width: 2; height: pl.height - pl.cut; color: m.acc }
  }

  Item {
    id: sky
    width: 760; height: 520
    anchors.centerIn: parent
    opacity: m.k * (1 - 0.85 * m.flow)
    scale: (0.92 + 0.08 * m.k) * (1 + 0.12 * m.flow)
    enabled: m.page === ""
    readonly property real rx: 300
    readonly property real ry: 120
    readonly property real tilt: -14
    WheelHandler { onWheel: function(e) { m.spin += e.angleDelta.y < 0 ? 36 : -36 } }

    // орбиты: две наклонные эллипсы, как у его систем на звёздной карте
    Repeater {
      model: [1, 0.7]
      Shape {
        required property real modelData
        anchors.centerIn: parent
        width: sky.rx * 2; height: sky.rx * 2
        rotation: sky.tilt
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeWidth: 1
          strokeColor: m.a(m.fg, modelData === 1 ? 0.16 : 0.08)
          fillColor: "transparent"
          PathAngleArc { centerX: sky.rx; centerY: sky.rx; radiusX: sky.rx * modelData; radiusY: sky.ry * modelData; startAngle: 0; sweepAngle: 360 }
        }
      }
    }
    // корабль: треугольник-стрелка с тонким свечением и подпись
    Item {
      anchors.centerIn: parent
      width: 120; height: 90
      Rectangle {
        anchors.centerIn: ship
        width: 90; height: 90; radius: 45
        gradient: Gradient {
          GradientStop { position: 0; color: "transparent" }
          GradientStop { position: 0.5; color: m.a(m.acc, 0.16) }
          GradientStop { position: 1; color: "transparent" }
        }
      }
      Shape {
        id: ship
        width: 40; height: 46
        anchors.horizontalCenter: parent.horizontalCenter
        y: 4
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeWidth: 1.5
          strokeColor: m.acc
          fillColor: m.a(m.acc, 0.18)
          startX: 20; startY: 0
          PathLine { x: 40; y: 46 }
          PathLine { x: 20; y: 34 }
          PathLine { x: 0; y: 46 }
          PathLine { x: 20; y: 0 }
        }
      }
      SpaceDecode {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 58
        text: m.hoverId !== "" ? (m.names[m.hoverId] || m.hoverId) : "ship // control"
        color: m.hoverId !== "" ? m.fg : m.a(m.fg, 0.5)
      }
    }
    // планеты
    Repeater {
      model: m.planets
      Item {
        id: pl
        required property var modelData
        required property int index
        readonly property real ang: (index / m.planets.length * 360 + m.spin + m.drift) * Math.PI / 180
        readonly property real ex: Math.cos(ang) * sky.rx
        readonly property real ey: Math.sin(ang) * sky.ry
        readonly property real tr: sky.tilt * Math.PI / 180
        // глубина: ближняя (внизу эллипса) — крупнее
        readonly property real depth: (Math.sin(ang) + 1) / 2
        readonly property bool lit: m.on(modelData[0])
        readonly property bool page: modelData[2] === "page"
        width: 56; height: 56
        x: sky.width / 2 + ex * Math.cos(tr) - ey * Math.sin(tr) - width / 2
        y: sky.height / 2 + ex * Math.sin(tr) + ey * Math.cos(tr) - height / 2
        z: depth
        scale: (0.72 + 0.4 * depth) * (hv.hovered ? 1.18 : 1)
        opacity: 0.55 + 0.45 * depth
        Behavior on scale { NumberAnimation { duration: 160 } }
        // атмосфера и шар
        Rectangle {
          anchors.centerIn: parent
          width: 56; height: 56; radius: 28
          color: "transparent"
          border.width: 1
          border.color: pl.lit ? m.a(m.acc, 0.6) : m.a(m.fg, 0.18)
        }
        Rectangle {
          anchors.centerIn: parent
          width: 42; height: 42; radius: 21
          gradient: Gradient {
            GradientStop { position: 0; color: pl.lit ? Qt.lighter(m.acc, 1.3) : m.a(m.fg, 0.32) }
            GradientStop { position: 1; color: pl.lit ? m.a(m.acc, 0.55) : m.a(m.bg, 0.9) }
          }
        }
        // кольцо у разделов
        Rectangle {
          visible: pl.page
          anchors.centerIn: parent
          width: 66; height: 14; radius: 7
          color: "transparent"
          border.width: 1
          border.color: m.a(m.acc, 0.55)
          rotation: -18
        }
        Text { anchors.centerIn: parent; text: pl.modelData[1]; color: pl.lit ? m.bg : m.fg; font.family: m.mono; font.pixelSize: 18 }
        HoverHandler { id: hv; cursorShape: Qt.PointingHandCursor; onHoveredChanged: m.hoverId = hovered ? pl.modelData[0] : (m.hoverId === pl.modelData[0] ? "" : m.hoverId) }
        TapHandler { onTapped: m.act(pl.modelData, pl.x + pl.width / 2, pl.y + pl.height / 2) }
      }
    }
  }

  // плашка раздела — планета подлетает к кораблю и разворачивается
  Plate {
    id: panel
    visible: m.flow > 0.01
    width: 60 + 460 * m.flow; height: 60 + 400 * m.flow
    cut: 14 * m.flow
    x: (m.width - width) / 2 + (m.from.x - sky.width / 2) * (1 - m.flow)
    y: (m.height - height) / 2 + (m.from.y - sky.height / 2) * (1 - m.flow)
    opacity: m.k
    MouseArea { anchors.fill: parent }
    Item {
      x: 18; y: 12; width: panel.width - 36; height: 26
      opacity: m.flow
      Text { id: pg; text: ({ wifi: "\u{F05A9}", bt: "\u{F00AF}", audio: "\u{F057E}" })[m.page] || ""; font.family: m.mono; font.pixelSize: 14; color: m.acc; anchors.verticalCenter: parent.verticalCenter }
      SpaceDecode { x: pg.width + 8; height: parent.height; text: m.names[m.page] || ""; color: m.fg }
      Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: m.a(m.acc, 0.25) }
    }
    SectionBody {
      id: sbody
      opacity: m.flow
      x: 18; y: 50; width: panel.width - 36; height: panel.height - 66
      md: m.md; page: m.page
      ink: m.fg; litFill: m.a(m.acc, 0.3); litInk: m.fg; hoverFill: m.a(m.acc, 0.1); line: m.a(m.acc, 0.35)
      radius: 0; size: 12; rowH: 34; field: m.a(m.fg, 0.05); font: m.mono; bar: "blocks"
    }
  }
}

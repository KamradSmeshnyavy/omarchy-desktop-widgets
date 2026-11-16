import QtQuick
import Quickshell
import Quickshell.Io

// Меню Super+M Cozytile — «полка вкладок» (свой, в облике Cozytile: язычки с S-образными боками, как вкладки его бара,
// тёмные карточки цвета фона, цвет выбора — magenta темы, JetBrains Mono). Сверху ряд язычков system · wi-fi ·
// bluetooth · sound; активный язычок светится и «вытягивает» под собой тёмную карточку — при смене вкладки карточка
// перелистывается вбок. Колесо и [ / ] листают вкладки; стрелки / Tab / Enter — по кнопкам (KeyNav), Esc — закрыть.
MenuBase {
  id: m
  readonly property color fg: host ? host.foreground : "white"
  readonly property color bg: host ? host.background : "black"
  property color sel: host ? host.accent : "magenta"
  function a(c, k) { return Qt.rgba(c.r, c.g, c.b, k) }
  readonly property string mono: Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : "monospace"
  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    printErrors: false
    onLoaded: { var r = String(text()).match(/^\s*magenta\s*=\s*"(#[0-9a-fA-F]{6})"/m); if (r) m.sel = r[1] }
  }
  readonly property var tabs: [["system", "\u{F0493}"], ["wifi", "\u{F05A9}"], ["bt", "\u{F00AF}"], ["audio", "\u{F057E}"]]
  readonly property string cur: page === "" ? "system" : page
  readonly property int ci: tabs.findIndex(function(t) { return t[0] === m.cur })
  property int dir: 1
  function go(i) { i = (i + tabs.length) % tabs.length; dir = i > ci ? 1 : -1; page = i === 0 ? "" : tabs[i][0]; flip.restart() }
  function back() { return false }
  function keys(e) {
    if (e.key === Qt.Key_BracketRight) { go(ci + 1); return true }
    if (e.key === Qt.Key_BracketLeft) { go(ci - 1); return true }
    return false
  }
  property real slide: 0
  NumberAnimation { id: flip; target: m; property: "slide"; from: 1; to: 0; duration: 260; easing.type: Easing.OutCubic }

  component Tab: Item {
    id: tb
    property string label: ""
    property string icon: ""
    property bool on: false
    signal hit()
    width: tl.implicitWidth + 52; height: 34
    Canvas {
      id: cv
      anchors.fill: parent
      property color c: tb.on ? m.bg : m.a(m.bg, 0.6)
      onCChanged: requestPaint()
      onPaint: { var x = getContext("2d"); x.reset(); x.fillStyle = c; var w = width, h = height
        x.beginPath(); x.moveTo(0, h); x.bezierCurveTo(12, h, 12, 0, 26, 0); x.lineTo(w - 26, 0); x.bezierCurveTo(w - 12, 0, w - 12, h, w, h); x.closePath(); x.fill() }
    }
    Text { id: tl; anchors.centerIn: parent; anchors.verticalCenterOffset: 2; text: tb.icon + "  " + tb.label; color: tb.on ? m.sel : m.a(m.fg, th.hovered ? 0.9 : 0.55); font.family: m.mono; font.pixelSize: 12 }
    HoverHandler { id: th; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: tb.hit() }
  }
  component Round: Rectangle {
    id: rb
    property string icon: ""
    property string label: ""
    property bool on: false
    signal hit()
    width: 120; height: 76; radius: 10
    color: on ? m.sel : (h.hovered ? m.a(m.fg, 0.12) : m.a(m.fg, 0.06))
    Column { anchors.centerIn: parent; spacing: 4
      Text { anchors.horizontalCenter: parent.horizontalCenter; text: rb.icon; color: rb.on ? m.bg : m.fg; font.family: m.mono; font.pixelSize: 20 }
      Text { anchors.horizontalCenter: parent.horizontalCenter; text: rb.label; color: rb.on ? m.bg : m.a(m.fg, 0.7); font.family: m.mono; font.pixelSize: 10 } }
    HoverHandler { id: h; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: rb.hit() }
  }

  Item {
    id: shelf
    width: 600; height: 470
    anchors.centerIn: parent
    opacity: m.k
    transform: Translate { y: (1 - m.k) * 16 }
    WheelHandler { onWheel: function(e) { m.go(m.ci + (e.angleDelta.y < 0 ? 1 : -1)) } }
    Row {
      x: 16; spacing: -14
      Repeater {
        model: m.tabs
        Tab { required property var modelData; required property int index; label: modelData[0]; icon: modelData[1]; on: m.ci === index; z: m.ci === index ? 2 : 0; onHit: m.go(index) }
      }
    }
    Rectangle {
      y: 34; width: parent.width; height: parent.height - 34; radius: 10; color: m.bg
      clip: true
      MouseArea { anchors.fill: parent }
      Item {
        anchors.fill: parent
        transform: Translate { x: m.slide * m.dir * 60 }
        opacity: 1 - m.slide
        // system
        Column {
          visible: m.cur === "system"
          x: 24; y: 22; spacing: 14
          Text { text: Qt.formatTime(new Date(), "HH:mm") + "  ·  " + (Quickshell.env("USER") || "") + "  ·  up " + String(m.st ? m.st.uptime : ""); color: m.fg; font.family: m.mono; font.pixelSize: 13 }
          Grid {
            columns: 4; spacing: 10
            Round { icon: "\u{F0594}"; label: "night"; on: !!m.st && m.st.night; onHit: m.st.toggleNight() }
            Round { icon: "\u{F009B}"; label: "silence"; on: !!m.st && m.st.dnd; onHit: m.st.toggleDnd() }
            Round { icon: "\u{F0176}"; label: "awake"; on: !!m.st && m.st.caffeine; onHit: m.st.toggleCaffeine() }
            Round { icon: "\u{F036C}"; label: "mic"; on: !!m.st && !m.st.micMuted; onHit: m.st.toggleMic() }
            Round { icon: "\u{F019E}"; label: "shot"; onHit: { m.close(); m.run(["omarchy-capture-screenshot"]) } }
            Round { icon: "\u{F0493}"; label: "tweak"; onHit: { m.close(); m.run(["omarchy-shell", "shell", "toggle", "kamradsmeshnyavy.customizer"]) } }
            Round { icon: "\u{F033E}"; label: "lock"; onHit: { m.close(); m.run(["omarchy-system-lock"]) } }
            Round { icon: "\u{F0425}"; label: "power"; onHit: { m.close(); m.host.powerOpen = true } }
          }
          Text { text: "[ ]  or wheel — tabs"; color: m.a(m.fg, 0.4); font.family: m.mono; font.pixelSize: 10 }
        }
        SectionBody {
          visible: m.cur !== "system"
          x: 18; y: 18; width: parent.width - 36; height: parent.height - 36
          md: m.md; page: m.cur
          ink: m.fg; litFill: m.sel; litInk: m.bg; radius: 7; font: m.mono; size: 12; rowH: 38; field: m.a(m.fg, 0.05)
        }
      }
    }
  }
}

import QtQuick
import Quickshell

// Меню Super+M Bruteon — «доска стикеров» (свой, в облике Bruteon: пастельные плитки с толстым контуром и жёсткой тенью,
// JetBrains Mono жирным). Плитки лежат на кремовой доске чуть вразнобой (каждая повёрнута на свой угол). Нажатая плитка
// «падает» на свою тень (сдвиг на 5 px, тень пропадает) и встаёт обратно; разделы Wi-Fi / Bluetooth / Sound раскрываются
// большой карточкой посреди доски, остальные плитки разъезжаются к краям и бледнеют. Клавиатура: стрелки / Tab / Enter
// (KeyNav), Esc — закрыть карточку, потом меню.
MenuBase {
  id: m
  readonly property color ink: host ? host.foreground : "#161110"
  readonly property color paper: host ? host.background : "#efe0d6"
  readonly property bool dark: 0.299 * paper.r + 0.587 * paper.g + 0.114 * paper.b < 0.5
  function mix(a, c, t) { return Qt.rgba(a.r + (c.r - a.r) * t, a.g + (c.g - a.g) * t, a.b + (c.b - a.b) * t, 1) }
  readonly property color card: dark ? mix(paper, ink, 0.07) : mix(paper, Qt.color("#ffffff"), 0.35)
  readonly property color dk: "#161110"
  readonly property string mono: Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : "monospace"
  readonly property var pastel: ({ peach: "#ffb77a", salmon: "#ffb3a1", green: "#c5e1a5", pink: "#ffcbd5", lavender: "#dcc4ec", blue: "#90caf9", yellow: "#ffd98a", white: "#fbf5f1" })
  property string pwFor: ""

  component Tile: Item {
    id: t
    property color fill: m.pastel.white
    property string icon: ""
    property string label: ""
    property string sub: ""
    property real tilt: 0
    property bool on: false
    property int r: 12
    signal hit()
    property real drop: 0
    rotation: tilt
    Rectangle { x: 5; y: 5; width: t.width; height: t.height; radius: t.r; color: m.ink; opacity: 1 - t.drop }
    Rectangle {
      x: 5 * t.drop - (hh.hovered && t.drop === 0 ? 2 : 0); y: x
      width: t.width; height: t.height; radius: t.r
      color: t.fill; border.width: 3; border.color: m.ink
      Column {
        anchors.centerIn: parent; spacing: 4
        Text { anchors.horizontalCenter: parent.horizontalCenter; visible: t.icon !== ""; text: t.icon; color: m.dk; font.pixelSize: t.height > 90 ? 30 : 20 }
        Text { anchors.horizontalCenter: parent.horizontalCenter; visible: t.label !== ""; text: t.label; color: m.dk; font.family: m.mono; font.pixelSize: 13; font.bold: true }
        Text { anchors.horizontalCenter: parent.horizontalCenter; visible: t.sub !== ""; text: t.sub; color: m.dk; opacity: 0.65; font.family: m.mono; font.pixelSize: 10; width: Math.min(implicitWidth, t.width - 16); elide: Text.ElideRight }
      }
      Rectangle { visible: t.on; anchors { top: parent.top; right: parent.right; margins: 8 } width: 10; height: 10; radius: 5; color: m.dk }
    }
    SequentialAnimation { id: dropAnim
      NumberAnimation { target: t; property: "drop"; to: 1; duration: 90; easing.type: Easing.OutCubic }
      ScriptAction { script: t.hit() }
      NumberAnimation { target: t; property: "drop"; to: 0; duration: 160; easing.type: Easing.OutBack } }
    HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: dropAnim.restart() }
  }
  component Row2: Item {
    id: rw
    property string text: ""
    property string tail: ""
    property bool on: false
    signal hit()
    width: 520; height: 40
    Rectangle { anchors.fill: parent; radius: 8; color: rw.on ? m.pastel.green : rh.hovered ? m.mix(m.card, m.ink, 0.08) : "transparent"; border.width: rw.on || rh.hovered ? 2 : 0; border.color: m.ink }
    Text { x: 14; anchors.verticalCenter: parent.verticalCenter; width: 380; elide: Text.ElideRight; text: rw.text; color: rw.on ? m.dk : m.ink; font.family: m.mono; font.pixelSize: 12; font.bold: rw.on }
    Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: rw.tail; color: rw.on ? m.dk : m.ink; opacity: 0.7; font.family: m.mono; font.pixelSize: 11 }
    HoverHandler { id: rh; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: rw.hit() }
  }

  // доска
  Item {
    id: board
    width: 760; height: 470
    anchors.centerIn: parent
    opacity: m.k
    scale: 0.94 + 0.06 * m.k
    Rectangle { x: 6; y: 6; width: board.width; height: board.height; radius: 16; color: m.ink }
    Rectangle { anchors.fill: parent; radius: 16; color: m.paper; border.width: 3; border.color: m.ink }
    MouseArea { anchors.fill: parent }   // клики по доске не закрывают меню
    Text { x: 24; y: 16; text: "☰ board · " + (Quickshell.env("USER") || ""); color: m.ink; font.family: m.mono; font.pixelSize: 12; font.bold: true }

    // плитки — разъезжаются, когда открыт раздел
    Item {
      id: tiles
      anchors.fill: parent
      opacity: m.page === "" ? 1 : 0.18
      scale: m.page === "" ? 1 : 1.12
      enabled: m.page === ""
      Behavior on opacity { NumberAnimation { duration: 220 } }
      Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
      Tile { x: 30; y: 52; width: 220; height: 130; tilt: -2; fill: m.pastel.peach; icon: "\u{F05A9}"; label: "Wi-Fi"; sub: m.st && m.st.wifi ? (m.st.ssid || "on") : "off"; on: !!m.st && m.st.wifi; onHit: m.page = "wifi" }
      Tile { x: 270; y: 46; width: 220; height: 130; tilt: 1.5; fill: m.pastel.lavender; icon: "\u{F00AF}"; label: "Bluetooth"; sub: m.st && m.st.bt ? "on" : "off"; on: !!m.st && m.st.bt; onHit: m.page = "bt" }
      Tile { x: 510; y: 54; width: 220; height: 130; tilt: -1; fill: m.pastel.green; icon: "\u{F057E}"; label: "Sound"; sub: m.st ? Math.round(m.st.vol * 100) + "%" + (m.st.muted ? " · muted" : "") : ""; onHit: m.page = "audio" }
      Tile { x: 34; y: 210; width: 160; height: 96; tilt: 1; fill: m.pastel.pink; icon: "\u{F0594}"; label: "Night"; on: !!m.st && m.st.night; onHit: m.st.toggleNight() }
      Tile { x: 212; y: 206; width: 160; height: 96; tilt: -1.5; fill: m.pastel.blue; icon: "\u{F009B}"; label: "Silence"; on: !!m.st && m.st.dnd; onHit: m.st.toggleDnd() }
      Tile { x: 390; y: 212; width: 160; height: 96; tilt: 2; fill: m.pastel.yellow; icon: "\u{F0176}"; label: "Awake"; on: !!m.st && m.st.caffeine; onHit: m.st.toggleCaffeine() }
      Tile { x: 568; y: 208; width: 160; height: 96; tilt: -0.5; fill: m.pastel.white; icon: "\u{F036C}"; label: "Mic"; on: !!m.st && !m.st.micMuted; onHit: m.st.toggleMic() }
      Tile { x: 36; y: 336; width: 150; height: 84; tilt: -1; fill: m.pastel.white; icon: "\u{F019E}"; label: "Shot"; onHit: { m.close(); m.run(["omarchy-capture-screenshot"]) } }
      Tile { x: 206; y: 332; width: 150; height: 84; tilt: 1.5; fill: m.pastel.lavender; icon: "\u{F0493}"; label: "Tweak"; onHit: { m.close(); m.run(["omarchy-shell", "shell", "toggle", "kamradsmeshnyavy.customizer"]) } }
      Tile { x: 376; y: 338; width: 150; height: 84; tilt: -2; fill: m.pastel.white; icon: "\u{F033E}"; label: "Lock"; onHit: { m.close(); m.run(["omarchy-system-lock"]) } }
      Tile { x: 546; y: 334; width: 180; height: 84; tilt: 1; fill: m.pastel.salmon; icon: "\u{F0425}"; label: "Power"; onHit: { m.close(); m.host.powerOpen = true } }
    }

    // большая карточка раздела
    Item {
      id: big
      visible: m.page !== ""
      width: 580; height: 380
      anchors.centerIn: parent
      scale: m.page !== "" ? 1 : 0.9
      Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
      Rectangle { x: 6; y: 6; width: big.width; height: big.height; radius: 14; color: m.ink }
      Rectangle {
        anchors.fill: parent; radius: 14; color: m.card; border.width: 3; border.color: m.ink
        MouseArea { anchors.fill: parent }
        Row {
          x: 24; y: 18; spacing: 10
          Text { text: ({ wifi: "\u{F05A9}  Wi-Fi", bt: "\u{F00AF}  Bluetooth", audio: "\u{F057E}  Sound" })[m.page] || ""; color: m.ink; font.family: m.mono; font.pixelSize: 16; font.bold: true }
        }
        Row {
          anchors.right: parent.right; anchors.rightMargin: 20; y: 12; spacing: 10
          Tile { visible: m.page === "wifi" || m.page === "bt"; width: 80; height: 32; r: 8; fill: (m.page === "wifi" ? m.st && m.st.wifi : m.st && m.st.bt) ? m.pastel.green : m.pastel.white; label: (m.page === "wifi" ? m.st && m.st.wifi : m.st && m.st.bt) ? "on" : "off"; onHit: m.page === "wifi" ? m.st.toggleWifi() : m.st.toggleBt() }
          Tile { visible: m.page === "bt"; width: 80; height: 32; r: 8; label: "scan"; onHit: m.md.scanBt() }
          Tile { width: 44; height: 32; r: 8; fill: m.pastel.pink; label: "✕"; onHit: m.page = "" }
        }
        Flickable {
          x: 28; y: 62; width: 524; height: 296; clip: true
          contentHeight: col.implicitHeight
          Column {
            id: col
            spacing: 6
            // Wi-Fi
            Repeater {
              model: m.page === "wifi" && m.md ? m.md.networks : []
              Row2 {
                required property var modelData
                text: (modelData.secure ? "\u{F033E}  " : "    ") + modelData.ssid
                tail: modelData.active ? "connected" : "▂▄▆█".slice(0, Math.max(1, Math.ceil(modelData.signal / 25)))
                on: modelData.active
                onHit: modelData.active ? m.md.disconnectWifi(modelData.ssid) : (modelData.secure ? m.pwFor = modelData.ssid : m.md.connectWifi(modelData.ssid, ""))
              }
            }
            Item {
              visible: m.page === "wifi" && m.pwFor !== ""
              width: 520; height: 44
              Rectangle { anchors.fill: parent; radius: 8; color: m.paper; border.width: 2; border.color: m.ink }
              TextInput {
                id: pw
                x: 14; width: 400; anchors.verticalCenter: parent.verticalCenter
                echoMode: TextInput.Password; color: m.ink; font.family: m.mono; font.pixelSize: 13
                focus: visible
                onVisibleChanged: if (visible) forceActiveFocus()
                Keys.onReturnPressed: { m.md.connectWifi(m.pwFor, text); text = ""; m.pwFor = "" }
                Keys.onEscapePressed: { text = ""; m.pwFor = "" }
                Text { visible: !parent.text.length; text: "password for " + m.pwFor; color: m.ink; opacity: 0.45; font: parent.font }
              }
            }
            // Bluetooth
            Repeater {
              model: m.page === "bt" && m.md ? m.md.devices : []
              Row2 {
                required property var modelData
                text: modelData.name
                tail: modelData.connected ? "connected" : modelData.paired ? "paired" : "new"
                on: modelData.connected
                onHit: m.md.toggleDevice(modelData)
              }
            }
            // Звук
            Item {
              visible: m.page === "audio"
              width: 520; height: 60
              property bool kbdNav: m.page === "audio"
              property real kbdRadius: 8
              function kbdPress() { m.st.setVol(m.st.vol > 0 ? 0 : 0.5) }
              function kbdAdjust(d) { m.st.setVol(Math.max(0, Math.min(1, m.st.vol + d * 0.05))) }
              Text { y: 4; text: "volume " + Math.round((m.st ? m.st.vol : 0) * 100) + "%"; color: m.ink; font.family: m.mono; font.pixelSize: 12; font.bold: true }
              Rectangle {
                y: 28; width: 520; height: 22; radius: 8; color: m.paper; border.width: 2; border.color: m.ink
                Rectangle { x: 3; y: 3; height: 16; radius: 5; width: Math.max(0, (parent.width - 6) * Math.min(1, m.st ? m.st.vol : 0)); color: m.pastel.green }
                MouseArea { anchors.fill: parent; onPressed: function(e) { m.st.setVol(Math.max(0, Math.min(1, e.x / width))) } onPositionChanged: function(e) { if (pressed) m.st.setVol(Math.max(0, Math.min(1, e.x / width))) } }
              }
            }
            Row2 { visible: m.page === "audio"; text: "\u{F036C}  microphone"; tail: m.st && m.st.micMuted ? "muted" : "on"; on: !!m.st && !m.st.micMuted; onHit: m.st.toggleMic() }
            Text { visible: m.page === "audio"; text: "output"; color: m.ink; opacity: 0.6; font.family: m.mono; font.pixelSize: 11 }
            Repeater {
              model: m.page === "audio" && m.md ? m.md.sinks : []
              Row2 {
                required property var modelData
                text: m.md.sinkName(modelData)
                on: m.md.defaultSink === modelData
                onHit: m.md.setSink(modelData)
              }
            }
          }
        }
      }
    }
  }
}

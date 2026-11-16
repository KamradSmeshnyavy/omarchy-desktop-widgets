import QtQuick
import Quickshell

// Меню Super+M Rumda — «карамельная капсула» (свой, в облике Rumda: узкая пилюля сбоку, песочные карточки светлым
// акцентом, коричневый текст, пиксельный Dogica). Слева по центру — вертикальная пилюля с кружками-разделами; выбранный
// кружок заливается карамелью и из него вбок раскрывается песочная карточка раздела (wi-fi / bluetooth / sound — списки,
// остальное — переключатели и кнопки), ползунки — толстые закруглённые столбики. Стрелки / Tab / Enter (KeyNav), Esc.
MenuBase {
  id: m
  readonly property color acc: host ? host.accent : "#c89060"
  readonly property color sand: Qt.tint(acc, Qt.rgba(1, 1, 1, 0.45))
  readonly property color brown: Qt.darker(acc, 1.6)
  readonly property string px: Qt.fontFamilies().indexOf("Dogica Pixel") !== -1 ? "Dogica Pixel" : "monospace"
  function a(c, k) { return Qt.rgba(c.r, c.g, c.b, k) }
  readonly property var items: [["wifi", "\u{F05A9}"], ["bt", "\u{F00AF}"], ["audio", "\u{F057E}"], ["sys", "\u{F0493}"], ["power", "\u{F0425}"]]
  property string cur: "sys"
  onPageChanged: if (page !== "") cur = page
  function section(name) { var p = ({ wifi: "wifi", bt: "bt", bluetooth: "bt", audio: "audio" })[name]; if (p) cur = p }
  function back() { return false }

  component Dot: Rectangle {
    id: d
    property string icon: ""
    property bool on: false
    signal hit()
    width: 52; height: 52; radius: 26
    color: on ? m.brown : (h.hovered ? m.a(m.brown, 0.15) : "transparent")
    border.width: 3; border.color: m.brown
    Text { anchors.centerIn: parent; text: d.icon; color: d.on ? m.sand : m.brown; font.pixelSize: 20 }
    HoverHandler { id: h; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: d.hit() }
  }
  component Pill: Rectangle {
    id: pl
    property string text: ""
    property bool on: false
    signal hit()
    width: 150; height: 40; radius: 20
    color: on ? m.brown : (h2.hovered ? m.a(m.brown, 0.12) : "transparent"); border.width: 2; border.color: m.brown
    Text { anchors.centerIn: parent; text: pl.text; color: pl.on ? m.sand : m.brown; font.family: m.px; font.pixelSize: 9 }
    HoverHandler { id: h2; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: pl.hit() }
  }

  Row {
    x: 28; anchors.verticalCenter: parent.verticalCenter
    spacing: 14
    opacity: m.k
    transform: Translate { x: (1 - m.k) * -40 }
    // пилюля
    Rectangle {
      width: 72; height: col.implicitHeight + 28; radius: 36
      color: m.sand; border.width: 3; border.color: Qt.tint(m.acc, Qt.rgba(1, 1, 1, 0.2))
      anchors.verticalCenter: parent.verticalCenter
      MouseArea { anchors.fill: parent }
      Column {
        id: col; anchors.centerIn: parent; spacing: 10
        Repeater { model: m.items; Dot { required property var modelData; icon: modelData[1]; on: m.cur === modelData[0]; onHit: m.cur = modelData[0] } }
      }
    }
    // карточка
    Rectangle {
      id: card
      width: 460; height: 440; radius: 26
      anchors.verticalCenter: parent.verticalCenter
      color: m.sand; border.width: 3; border.color: Qt.tint(m.acc, Qt.rgba(1, 1, 1, 0.2))
      clip: true
      MouseArea { anchors.fill: parent }
      Text { x: 24; y: 20; text: ({ wifi: "wi-fi", bt: "bluetooth", audio: "sound", sys: "rumda", power: "power" })[m.cur]; color: m.brown; font.family: m.px; font.pixelSize: 14 }
      SectionBody {
        visible: ["wifi", "bt", "audio"].indexOf(m.cur) !== -1
        x: 20; y: 52; width: card.width - 40; height: card.height - 72
        md: m.md; page: m.cur
        ink: m.brown; litFill: m.brown; litInk: m.sand; radius: 20; font: m.px; size: 9; rowH: 40; field: m.a(m.brown, 0.08)
      }
      Grid {
        visible: m.cur === "sys"
        x: 24; y: 60; columns: 2; spacing: 12
        Pill { text: "night"; on: !!m.st && m.st.night; onHit: m.st.toggleNight() }
        Pill { text: "silence"; on: !!m.st && m.st.dnd; onHit: m.st.toggleDnd() }
        Pill { text: "awake"; on: !!m.st && m.st.caffeine; onHit: m.st.toggleCaffeine() }
        Pill { text: "mic"; on: !!m.st && !m.st.micMuted; onHit: m.st.toggleMic() }
        Pill { text: "screenshot"; onHit: { m.close(); m.run(["omarchy-capture-screenshot"]) } }
        Pill { text: "customizer"; onHit: { m.close(); m.run(["omarchy-shell", "shell", "toggle", "kamradsmeshnyavy.customizer"]) } }
      }
      // толстые столбики громкости и яркости
      Row {
        visible: m.cur === "sys"
        x: 24; y: 250; spacing: 24
        Repeater {
          model: [["vol", m.st ? m.st.vol : 0, 0], ["light", m.st ? m.st.bright : 0, 1]]
          Column {
            required property var modelData
            spacing: 6
            Rectangle {
              width: 48; height: 140; radius: 24; color: m.a(m.brown, 0.15)
              property bool kbdNav: true
              property real kbdRadius: 24
              function kbdPress() {}
              function kbdAdjust(d) { var v = Math.max(0, Math.min(1, modelData[1] + d * 0.05)); if (modelData[2] === 0) m.st.setVol(v); else m.st.setBright(v) }
              Rectangle { anchors.bottom: parent.bottom; width: 48; radius: 24; height: Math.max(48, parent.height * Math.max(0, modelData[1])); color: m.brown }
              MouseArea { anchors.fill: parent; onPressed: function(e) { var v = 1 - e.y / height; if (modelData[2] === 0) m.st.setVol(v); else m.st.setBright(v) } }
            }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData[0]; color: m.brown; font.family: m.px; font.pixelSize: 8 }
          }
        }
      }
      Column {
        visible: m.cur === "power"
        x: 24; y: 60; spacing: 12
        Pill { width: 300; text: "lock"; onHit: { m.close(); m.run(["omarchy-system-lock"]) } }
        Pill { width: 300; text: "suspend"; onHit: { m.close(); m.run(["systemctl", "suspend"]) } }
        Pill { width: 300; text: "power menu"; onHit: { m.close(); m.host.powerOpen = true } }
      }
    }
  }
}

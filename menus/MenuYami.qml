import QtQuick
import Quickshell

// Меню Super+M yami — «пиксельный терминал» (свой, в облике yami: графит, рамка в пиксель, жёсткая тень 3 px, Tiny5,
// один акцент). Окно консоли 620 × 440: шапка «yami@host:~$ settings», ниже приглашение и разделы строками
// «> wifi», «> bluetooth», «> audio», «> night [x]» …; выбранная строка — акцентом с блочным курсором ▌, внутри раздела —
// списки строками «[x] имя  ▂▄▆», громкость — блоками █▒. Буквы: w — wifi, b — bluetooth, a — audio, n — ночь, d — dnd,
// q — закрыть; стрелки / Tab / Enter (KeyNav), Esc — назад / закрыть. Каждая строка печатается с задержкой, как вывод.
MenuBase {
  id: m
  body: sbody
  readonly property color fg: host ? host.foreground : "white"
  readonly property color bg: host ? host.background : "black"
  readonly property color acc: host ? host.accent : "white"
  readonly property color panel: Qt.rgba(bg.r * 0.85, bg.g * 0.85, bg.b * 0.85, 1)
  function a(c, k) { return Qt.rgba(c.r, c.g, c.b, k) }
  readonly property string px: Qt.fontFamilies().indexOf("Tiny5") !== -1 ? "Tiny5" : "monospace"
  readonly property string host_: Quickshell.env("HOSTNAME") || "yami"
  property bool blink: true
  Timer { interval: 530; repeat: true; running: m.open; onTriggered: m.blink = !m.blink }

  function keys(e) {
    if (m.page !== "") return false
    var map = ({}); map[Qt.Key_W] = "wifi"; map[Qt.Key_B] = "bt"; map[Qt.Key_A] = "audio"
    if (map[e.key]) { m.page = map[e.key]; return true }
    if (e.key === Qt.Key_N) { m.st.toggleNight(); return true }
    if (e.key === Qt.Key_D) { m.st.toggleDnd(); return true }
    if (e.key === Qt.Key_Q) { m.close(); return true }
    return false
  }

  component Cmd: Item {
    id: c
    property string text: ""
    property string hint: ""
    property bool lit: false
    property bool isToggle: false
    property int index: 0
    signal hit()
    width: 572; height: 26
    opacity: m.k > 0.5 ? 1 : 0
    Behavior on opacity { SequentialAnimation { PauseAnimation { duration: c.index * 35 } NumberAnimation { duration: 60 } } }
    Rectangle { anchors.fill: parent; color: ch.hovered ? m.a(m.acc, 0.18) : "transparent" }
    Text { x: 6; anchors.verticalCenter: parent.verticalCenter; text: "> " + c.text + (c.isToggle ? (c.lit ? "  [x]" : "  [ ]") : ""); color: c.lit ? m.acc : m.fg; font.family: m.px; font.pixelSize: 13 }
    Text { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: c.hint; color: m.a(m.fg, 0.45); font.family: m.px; font.pixelSize: 11 }
    HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: c.hit() }
  }

  Item {
    id: win
    width: 620; height: 440
    anchors.centerIn: parent
    opacity: m.k
    Rectangle { x: 3; y: 3; width: win.width; height: win.height; color: Qt.rgba(0, 0, 0, 0.6) }
    Rectangle {
      anchors.fill: parent; color: m.panel; border.width: 1; border.color: m.a(m.fg, 0.2)
      MouseArea { anchors.fill: parent }
      Rectangle { width: parent.width; height: 24; color: m.a(m.fg, 0.06)
        Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: (Quickshell.env("USER") || "") + "@" + m.host_ + ":~$ settings" + (m.page !== "" ? " " + m.page : ""); color: m.a(m.fg, 0.7); font.family: m.px; font.pixelSize: 11 }
        Row { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 4
          Repeater { model: 3; Rectangle { width: 10; height: 10; color: index === 2 ? m.acc : m.a(m.fg, 0.25) } } }
      }
      Column {
        visible: m.page === ""
        x: 20; y: 40; spacing: 2
        Text { text: "yami settings — " + Qt.formatDate(new Date(), "ddd dd.MM").toLowerCase() + " · up " + String(m.st ? m.st.uptime : ""); color: m.a(m.fg, 0.5); font.family: m.px; font.pixelSize: 11 }
        Item { width: 1; height: 8 }
        Cmd { index: 0; text: "wifi"; hint: (m.st && m.st.wifi ? (m.st.ssid || "on") : "off") + "  [w]"; onHit: m.page = "wifi" }
        Cmd { index: 1; text: "bluetooth"; hint: (m.st && m.st.bt ? "on" : "off") + "  [b]"; onHit: m.page = "bt" }
        Cmd { index: 2; text: "audio"; hint: Math.round((m.st ? m.st.vol : 0) * 100) + "%  [a]"; onHit: m.page = "audio" }
        Cmd { index: 3; text: "night"; isToggle: true; lit: !!m.st && m.st.night; hint: "[n]"; onHit: m.st.toggleNight() }
        Cmd { index: 4; text: "dnd"; isToggle: true; lit: !!m.st && m.st.dnd; hint: "[d]"; onHit: m.st.toggleDnd() }
        Cmd { index: 5; text: "awake"; isToggle: true; lit: !!m.st && m.st.caffeine; onHit: m.st.toggleCaffeine() }
        Cmd { index: 6; text: "mic"; isToggle: true; lit: !!m.st && !m.st.micMuted; onHit: m.st.toggleMic() }
        Cmd { index: 7; text: "screenshot"; onHit: { m.close(); m.run(["omarchy-capture-screenshot"]) } }
        Cmd { index: 8; text: "customizer"; onHit: { m.close(); m.run(["omarchy-shell", "shell", "toggle", "kamradsmeshnyavy.customizer"]) } }
        Cmd { index: 9; text: "lock"; onHit: { m.close(); m.run(["omarchy-system-lock"]) } }
        Cmd { index: 10; text: "power"; onHit: { m.close(); m.host.powerOpen = true } }
        Row { spacing: 0; Text { text: "> "; color: m.fg; font.family: m.px; font.pixelSize: 13 } Rectangle { width: 9; height: 15; color: m.acc; opacity: m.blink ? 1 : 0 } }
      }
      SectionBody {
        id: sbody
        visible: m.page !== ""
        x: 16; y: 40; width: 588; height: 384
        md: m.md; page: m.page
        ink: m.fg; litFill: m.acc; litInk: m.panel; radius: 0; font: m.px; size: 12; rowH: 28
        textOn: "[x] "; textOff: "[ ] "; bar: "blocks"
      }
    }
  }
}

import QtQuick
import Quickshell

// Дашборд yami (свой, в облике yami — Trendorin/yami, MIT: тёмный графит, один акцент, рамки в пиксель, жёсткая тень
// 3 px, пиксельный Tiny5). 780 × 430: слева крупное время Tiny5 с тенью, двоеточие акцентом, дата, шкала дня из
// 16 штрихов и uptime; справа cpu / mem — столбики истории акцентом, disk / temp — полосы; ниже ряд квадратных ячеек-
// переключателей (wifi, bt, dnd, night, idle, mic), строка плеера «♫ трек — исполнитель» с полосами визуализатора и
// [<<] [>] [>>], внизу sleep / reboot / power off. Всё кликается и ходит с клавиатуры (KeyNav дашборда).
Item {
  id: ym
  required property var host
  property real rise: 1
  readonly property bool live: rise > 0.01
  width: 780
  height: 430
  opacity: rise
  transform: Translate { y: (1 - ym.rise) * -12 }

  readonly property color fg: host.foreground
  readonly property color bg: host.background
  readonly property color acc: host.accent
  readonly property color panel: Qt.rgba(bg.r * 0.85, bg.g * 0.85, bg.b * 0.85, 1)
  function a(c, k) { return Qt.rgba(c.r, c.g, c.b, k) }
  readonly property string px: Qt.fontFamilies().indexOf("Tiny5") !== -1 ? "Tiny5" : host.fontFamily

  SurfState { id: st; live: ym.live }
  SysStats { id: ss; live: ym.live }
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: ym.live; triggeredOnStart: true; onTriggered: ym.now = new Date() }

  component Box: Item {
    default property alias content: inner.data
    property string title: ""
    Rectangle { x: 3; y: 3; width: parent.width; height: parent.height; color: Qt.rgba(0, 0, 0, 0.55) }
    Rectangle {
      anchors.fill: parent; color: ym.panel; border.width: 1; border.color: ym.a(ym.fg, 0.16)
      Text { x: 10; y: 6; visible: parent.parent.title !== ""; text: "[ " + parent.parent.title + " ]"; color: ym.a(ym.fg, 0.55); font.family: ym.px; font.pixelSize: 10 }
      Item { id: inner; anchors.fill: parent }
    }
  }
  component Cell: Rectangle {
    id: c
    property string label: ""
    property bool on: false
    signal hit()
    width: 70; height: 36
    color: on ? ym.acc : (h.hovered ? ym.a(ym.fg, 0.08) : "transparent")
    border.width: 1; border.color: on ? ym.acc : ym.a(ym.fg, 0.3)
    Text { anchors.centerIn: parent; text: c.label; color: c.on ? ym.panel : ym.fg; font.family: ym.px; font.pixelSize: 11 }
    HoverHandler { id: h; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: c.hit() }
  }

  // время
  Box {
    width: 300; height: 210; title: "clock"
    Item {
      x: 18; y: 30; width: digits.implicitWidth + 4; height: digits.implicitHeight + 4
      Row { x: 4; y: 4; Repeater { model: [Qt.formatTime(ym.now, "HH"), ":", Qt.formatTime(ym.now, "mm")]; Text { required property var modelData; text: modelData; color: Qt.rgba(0, 0, 0, 0.65); font.family: ym.px; font.pixelSize: 78 } } }
      Row { id: digits; Repeater { model: [Qt.formatTime(ym.now, "HH"), ":", Qt.formatTime(ym.now, "mm")]; Text { required property var modelData; required property int index; text: modelData; color: index === 1 ? ym.acc : ym.fg; font.family: ym.px; font.pixelSize: 78 } } }
    }
    Text { x: 22; y: 126; text: Qt.formatDate(ym.now, "ddd dd.MM.yyyy").toLowerCase(); color: ym.a(ym.fg, 0.7); font.family: ym.px; font.pixelSize: 13 }
    Row {
      x: 22; y: 152; spacing: 4
      Repeater {
        model: 16
        Rectangle { required property int index; width: 12; height: 10; color: index < Math.floor((ym.now.getHours() * 60 + ym.now.getMinutes()) / 1440 * 16) ? ym.acc : ym.a(ym.fg, 0.14) }
      }
    }
    Text { x: 22; y: 176; text: "up " + String(st.uptime || "—"); color: ym.a(ym.fg, 0.5); font.family: ym.px; font.pixelSize: 10; width: 260; elide: Text.ElideRight }
  }

  // загрузка
  Box {
    x: 312; width: 468; height: 210; title: "system"
    Row {
      x: 14; y: 28; spacing: 14
      Repeater {
        model: [["cpu", ss.cpuHist, ss.cpu], ["mem", ss.memHist, ss.mem]]
        Column {
          required property var modelData
          spacing: 4
          Text { text: modelData[0] + "  " + Math.round(modelData[2] * 100) + "%"; color: ym.fg; font.family: ym.px; font.pixelSize: 11 }
          Rectangle {
            width: 212; height: 84; color: "transparent"; border.width: 1; border.color: ym.a(ym.fg, 0.12)
            Row {
              anchors.bottom: parent.bottom; anchors.bottomMargin: 2; x: 2; spacing: 1
              Repeater { model: 30; Rectangle { required property int index; readonly property var h: modelData[1]; readonly property real v: h.length > index - (30 - h.length) && index >= 30 - h.length ? h[index - (30 - h.length)] : 0
                width: 6; height: Math.max(1, v * 78); anchors.bottom: parent ? parent.bottom : undefined; color: ym.acc; opacity: 0.4 + 0.6 * v } }
            }
          }
        }
      }
    }
    Column {
      x: 14; y: 150; spacing: 6
      Repeater {
        model: [["disk", ss.disk], ["temp", ss.temp]]
        Row {
          required property var modelData
          spacing: 8
          Text { width: 40; text: modelData[0]; color: ym.fg; font.family: ym.px; font.pixelSize: 10 }
          Rectangle { width: 340; height: 8; color: ym.a(ym.fg, 0.12); anchors.verticalCenter: parent.verticalCenter
            Rectangle { width: parent.width * modelData[1]; height: 8; color: modelData[1] > 0.85 ? ym.host.urgent : ym.acc } }
          Text { text: Math.round(modelData[1] * 100) + "%"; color: ym.a(ym.fg, 0.7); font.family: ym.px; font.pixelSize: 10 }
        }
      }
    }
  }

  // переключатели
  Box {
    y: 222; width: 300; height: 120; title: "toggles"
    Grid {
      x: 14; y: 30; columns: 3; spacing: 8
      Cell { label: "wifi"; on: st.wifi; onHit: st.toggleWifi() }
      Cell { label: "bt"; on: st.bt; onHit: st.toggleBt() }
      Cell { label: "dnd"; on: st.dnd; onHit: st.toggleDnd() }
      Cell { label: "night"; on: st.night; onHit: st.toggleNight() }
      Cell { label: "awake"; on: st.caffeine; onHit: st.toggleCaffeine() }
      Cell { label: "mic"; on: !st.micMuted; onHit: st.toggleMic() }
    }
  }

  // плеер
  Box {
    id: pl
    x: 312; y: 222; width: 468; height: 120; title: "player"
    readonly property var p: ym.host.player
    Text { x: 14; y: 28; width: 440; elide: Text.ElideRight; text: "♫ " + (pl.p && pl.p.trackTitle ? pl.p.trackTitle + " — " + (pl.p.trackArtist || "") : "silence — nothing playing"); color: ym.fg; font.family: ym.px; font.pixelSize: 13 }
    Row {
      x: 14; y: 52; height: 34; spacing: 3
      Repeater { model: 34; Rectangle { required property int index; readonly property var lv: ym.host.levels || []; readonly property real v: lv.length ? Math.min(1, Number(lv[Math.floor(index * lv.length / 34)] || 0)) : 0.05
        width: 5; height: 3 + 30 * v; anchors.bottom: parent ? parent.bottom : undefined; color: ym.acc; opacity: 0.35 + 0.65 * v } }
    }
    Row {
      anchors.right: parent.right; anchors.rightMargin: 14; y: 58; spacing: 4
      Cell { width: 34; height: 24; label: "<<"; onHit: if (pl.p) pl.p.previous() }
      Cell { width: 34; height: 24; label: pl.p && pl.p.isPlaying ? "||" : ">"; on: !!pl.p && pl.p.isPlaying; onHit: if (pl.p) pl.p.togglePlaying() }
      Cell { width: 34; height: 24; label: ">>"; onHit: if (pl.p) pl.p.next() }
    }
    Rectangle { x: 14; y: 98; width: 440; height: 2; color: ym.a(ym.fg, 0.12)
      Rectangle { height: 2; color: ym.acc; width: pl.p && pl.p.length > 0 ? parent.width * Math.min(1, pl.p.position / pl.p.length) : 0 } }
  }

  // питание
  Row {
    y: 356; spacing: 8
    Repeater {
      model: [["lock", ["omarchy-system-lock"]], ["sleep", ["systemctl", "suspend"]], ["reboot", ["omarchy-shell", "widgets", "togglePower"]], ["power off", ["omarchy-shell", "widgets", "togglePower"]]]
      Cell {
        required property var modelData
        width: 186; height: 34; label: modelData[0]
        onHit: { ym.host.dashboardOpen = false; Quickshell.execDetached(modelData[1]) }
      }
    }
  }
  Text { anchors.right: parent.right; y: 404; text: (Quickshell.env("USER") || "") + "@yami · " + Qt.formatTime(ym.now, "HH:mm:ss"); color: ym.a(ym.fg, 0.4); font.family: ym.px; font.pixelSize: 10 }
}

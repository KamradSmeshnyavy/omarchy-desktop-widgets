import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io

// Дашборд Cozytile (свой, в облике Cozytile — Darkkal44, только облик: тёмные карточки цвета фона темы со скруглением
// 10, язычки с S-образными боками как вкладки его бара, цвет выбора — magenta темы, JetBrains Mono, шапка-обои как у
// его лаунчера). 720 × 440: шапка — текущие обои, на ней язычок «cozytile» и крупные часы с датой; ряд карточек —
// погода, система (cpu / mem / disk скруглёнными полосами), плеер (обложка, трек, ⏮ ⏯ ⏭, прогресс); низ —
// круглые переключатели (wifi, bt, dnd, night, mic), ползунки громкости и яркости (←/→ с клавиатуры), пять значков
// питания (lock, suspend, logout, reboot, shutdown — последние три через меню выключения).
Item {
  id: cz
  required property var host
  property real rise: 1
  readonly property bool live: rise > 0.01
  width: 720
  height: 440
  opacity: rise
  transform: Translate { y: (1 - cz.rise) * -12 }

  readonly property color fg: host.foreground
  readonly property color bg: host.background
  readonly property color card: Qt.rgba(bg.r * 0.8 + fg.r * 0.06, bg.g * 0.8 + fg.g * 0.06, bg.b * 0.8 + fg.b * 0.06, 1)
  property color sel: host.accent
  function a(c, k) { return Qt.rgba(c.r, c.g, c.b, k) }
  readonly property string mono: Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : host.fontFamily
  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    printErrors: false; watchChanges: true
    onLoaded: { var m = String(text()).match(/^\s*magenta\s*=\s*"(#[0-9a-fA-F]{6})"/m); if (m) cz.sel = m[1] }
    onFileChanged: reload()
  }

  SurfState { id: st; live: cz.live }
  SysStats { id: ss; live: cz.live }
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: cz.live; triggeredOnStart: true; onTriggered: cz.now = new Date() }

  component Tab: Item {
    property string text: ""
    width: tt.implicitWidth + 44; height: 24
    Canvas {
      anchors.fill: parent
      onPaint: { var c = getContext("2d"); c.reset(); c.fillStyle = cz.card; var w = width, h = height
        c.beginPath(); c.moveTo(0, h); c.bezierCurveTo(10, h, 10, 0, 22, 0); c.lineTo(w - 22, 0); c.bezierCurveTo(w - 10, 0, w - 10, h, w, h); c.closePath(); c.fill() }
    }
    Text { id: tt; anchors.centerIn: parent; anchors.verticalCenterOffset: 2; text: parent.text; color: cz.sel; font.family: cz.mono; font.pixelSize: 11 }
  }
  component Card: Item {
    default property alias content: body.data
    property string tab: ""
    Tab { x: 14; text: parent.tab }
    Rectangle { id: body; y: 22; width: parent.width; height: parent.height - 22; radius: 10; color: cz.card }
  }
  component Round: Rectangle {
    id: rb
    property string icon: ""
    property bool on: false
    signal hit()
    width: 44; height: 44; radius: 22
    color: on ? cz.sel : (h.hovered ? cz.a(cz.fg, 0.12) : cz.a(cz.fg, 0.06))
    Text { anchors.centerIn: parent; text: rb.icon; color: rb.on ? cz.bg : cz.fg; font.family: cz.mono; font.pixelSize: 18 }
    HoverHandler { id: h; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: rb.hit() }
  }
  component Slide: Item {
    id: sl
    property string icon: ""
    property real value: 0
    signal moved(real v)
    // клавиатура: KeyNav берёт как цель, ←/→ — шаг 5 %
    property bool kbdNav: true
    property real kbdRadius: 8
    function kbdPress() {}
    function kbdAdjust(d) { moved(Math.max(0, Math.min(1, value + d * 0.05))) }
    width: 300; height: 30
    Text { anchors.verticalCenter: parent.verticalCenter; text: sl.icon; color: cz.fg; font.family: cz.mono; font.pixelSize: 16 }
    Rectangle {
      x: 30; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 30; height: 8; radius: 4; color: cz.a(cz.fg, 0.12)
      Rectangle { width: parent.width * Math.max(0, Math.min(1, sl.value)); height: 8; radius: 4; color: cz.sel }
      MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor
        onPressed: function(e) { sl.moved(Math.max(0, Math.min(1, e.x / width))) }
        onPositionChanged: function(e) { if (pressed) sl.moved(Math.max(0, Math.min(1, e.x / width))) } }
    }
  }

  // шапка
  Rectangle {
    width: parent.width; height: 132; radius: 10; color: cz.card; clip: true
    Image { id: wall; anchors.fill: parent; source: "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/current/background"; fillMode: Image.PreserveAspectCrop; sourceSize.width: 1440; asynchronous: true; cache: false; visible: false }
    Rectangle { id: wmask; anchors.fill: parent; radius: 10; visible: false; layer.enabled: true }
    MultiEffect { anchors.fill: parent; source: wall; maskEnabled: true; maskSource: wmask; maskThresholdMin: 0.5 }
    Rectangle { anchors.fill: parent; radius: 10; gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: cz.a(cz.bg, 0.85) } GradientStop { position: 0.6; color: cz.a(cz.bg, 0.2) } GradientStop { position: 1; color: "transparent" } } }
    Column {
      x: 28; anchors.verticalCenter: parent.verticalCenter; spacing: 2
      Text { text: Qt.formatTime(cz.now, "HH:mm"); color: cz.fg; font.family: cz.mono; font.pixelSize: 54; font.bold: true }
      Text { text: Qt.formatDate(cz.now, "dddd, d MMMM").toLowerCase(); color: cz.sel; font.family: cz.mono; font.pixelSize: 13 }
    }
    Rectangle {
      anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter
      width: hi.implicitWidth + 28; height: 32; radius: 7; color: cz.bg
      Text { id: hi; anchors.centerIn: parent; text: " " + (Quickshell.env("USER") || "") + " · up " + String(st.uptime || "—"); color: cz.fg; font.family: cz.mono; font.pixelSize: 11 }
    }
  }

  // ряд карточек
  Row {
    y: 142; spacing: 12
    Card {
      width: 196; height: 150; tab: " weather"
      readonly property var w: cz.host.weather
      Column {
        anchors.centerIn: parent; spacing: 4
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.parent.w && parent.parent.parent.w.temp !== undefined ? Math.round(parent.parent.parent.w.temp) + "°" : "—"; color: cz.fg; font.family: cz.mono; font.pixelSize: 40; font.bold: true }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.parent.w && parent.parent.parent.w.city ? String(parent.parent.parent.w.city) : "no city"; color: cz.sel; font.family: cz.mono; font.pixelSize: 12 }
      }
    }
    Card {
      width: 220; height: 150; tab: " system"
      Column {
        x: 16; y: 18; spacing: 14
        Repeater {
          model: [["cpu", ss.cpu], ["mem", ss.mem], ["disk", ss.disk]]
          Row {
            required property var modelData
            spacing: 10
            Text { width: 34; text: modelData[0]; color: cz.fg; font.family: cz.mono; font.pixelSize: 11 }
            Rectangle { width: 120; height: 8; radius: 4; color: cz.a(cz.fg, 0.12); anchors.verticalCenter: parent.verticalCenter
              Rectangle { width: parent.width * modelData[1]; height: 8; radius: 4; color: cz.sel } }
            Text { text: Math.round(modelData[1] * 100) + "%"; color: cz.a(cz.fg, 0.6); font.family: cz.mono; font.pixelSize: 10 }
          }
        }
      }
    }
    Card {
      id: pc
      width: 280; height: 150; tab: "󰎆 playing"
      readonly property var p: cz.host.player
      Rectangle {
        x: 14; y: 14; width: 72; height: 72; radius: 8; color: cz.a(cz.fg, 0.08); clip: true
        Image { anchors.fill: parent; source: pc.p ? String(pc.p.trackArtUrl || "") : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true }
      }
      Column {
        x: 98; y: 18; width: 168; spacing: 4
        Text { width: parent.width; elide: Text.ElideRight; text: pc.p && pc.p.trackTitle ? pc.p.trackTitle : "nothing playing"; color: cz.fg; font.family: cz.mono; font.pixelSize: 12; font.bold: true }
        Text { width: parent.width; elide: Text.ElideRight; text: pc.p ? String(pc.p.trackArtist || "") : ""; color: cz.a(cz.fg, 0.6); font.family: cz.mono; font.pixelSize: 10 }
      }
      Row {
        x: 98; y: 60; spacing: 14
        Repeater {
          model: [["\u{F04AE}", "previous"], [pc.p && pc.p.isPlaying ? "\u{F03E4}" : "\u{F040A}", "togglePlaying"], ["\u{F04AD}", "next"]]
          Text {
            required property var modelData
            text: modelData[0]; color: ph.hovered ? cz.sel : cz.fg; font.pixelSize: 20
            HoverHandler { id: ph; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: if (pc.p) pc.p[modelData[1]]() }
          }
        }
      }
      Rectangle { x: 14; y: 102; width: 252; height: 4; radius: 2; color: cz.a(cz.fg, 0.12)
        Rectangle { height: 4; radius: 2; color: cz.sel; width: pc.p && pc.p.length > 0 ? parent.width * Math.min(1, pc.p.position / pc.p.length) : 0 } }
    }
  }

  // низ
  Card {
    y: 304; width: parent.width; height: 136; tab: " controls"
    Row {
      x: 18; y: 22; spacing: 10
      Round { icon: "\u{F05A9}"; on: st.wifi; onHit: st.toggleWifi() }
      Round { icon: "\u{F00AF}"; on: st.bt; onHit: st.toggleBt() }
      Round { icon: "\u{F009B}"; on: st.dnd; onHit: st.toggleDnd() }
      Round { icon: "\u{F0594}"; on: st.night; onHit: st.toggleNight() }
      Round { icon: "\u{F036C}"; on: !st.micMuted; onHit: st.toggleMic() }
    }
    Column {
      x: 300; y: 16; spacing: 6
      Slide { icon: "\u{F057E}"; value: st.vol; onMoved: function(v) { st.setVol(v) } }
      Slide { visible: st.bright >= 0; icon: "\u{F00DF}"; value: st.bright; onMoved: function(v) { st.setBright(v) } }
    }
    Row {
      x: 18; y: 76; spacing: 10
      Repeater {
        model: [["\u{F033E}", ["omarchy-system-lock"]], ["\u{F04B2}", ["systemctl", "suspend"]], ["\u{F0343}", ["omarchy-shell", "widgets", "togglePower"]], ["\u{F0709}", ["omarchy-shell", "widgets", "togglePower"]], ["\u{F0425}", ["omarchy-shell", "widgets", "togglePower"]]]
        Round {
          required property var modelData
          width: 44; height: 36; radius: 10; icon: modelData[0]
          onHit: { cz.host.dashboardOpen = false; Quickshell.execDetached(modelData[1]) }
        }
      }
    }
  }
}

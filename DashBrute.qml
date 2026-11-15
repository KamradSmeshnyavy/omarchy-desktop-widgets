import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Дашборд Bruteon (dashStyle "bruteon", по мотивам Bruteon, Darkkal44 — облик с его скриншота, код свой): необрутализм —
// кремовые карточки с тёмным контуром и жёсткой тенью, внутри — плитки с той же тенью, пастельные заливки.
//   1 колонка — профиль (аватар в плитке, имя, user@host, «● Online») и столбик приложений (Firefox, Terminal, Files,
//     Spotify, Editor, Discord — цветной значок и подпись);
//   2 колонка — часы «07:47 PM │ WEDNESDAY / August 12, 2026»; погода (плитка «21°C │ Clear Sky», плитка луны / солнца,
//     цитата по времени суток);
//   3 колонка — звук и яркость: значки на плитках, высокие ползунки (лосось / зелёный), проценты;
//   4 колонка — «System Specs»: шесть плиток (OS, WM, Shell, Host, Uptime, Packages) с цветными значками;
//   ниже — плеер (обложка, название, исполнитель, пастельная волна точек от cava, время, назад / пауза / вперёд), CPU / RAM
//   / Disk полосами, ряд ссылок (GitHub, Reddit, YouTube, WhatsApp, Gmail, Twitch) на пастельных плитках.
Item {
  id: b

  required property var host
  property real rise: 1
  readonly property color ink: "#161110"
  readonly property color paper: "#efe0d6"
  readonly property color card: "#f5ebe6"
  readonly property color tileC: "#fbf3ee"
  readonly property color muted: "#885643"
  readonly property var pastel: ({ peach: "#ffb77a", salmon: "#ffb3a1", red: "#ff8a80", green: "#c5e1a5", pink: "#ffcbd5",
                                   lavender: "#c2c3e9", blue: "#90caf9", grey: "#d4e0e0", yellow: "#ffd98a", purple: "#d8b4f0" })
  readonly property var cava: ["#ffb3a1", "#ffbfbb", "#ffcbd5", "#f2c16a", "#e6b800", "#d5cc52", "#c5e1a5", "#87aeaa", "#4a7bb0", "#b478c8"]
  readonly property string mono: Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : host.fontFamily
  readonly property bool live: rise > 0.01

  implicitWidth: 820
  implicitHeight: 490
  opacity: Math.min(1, rise * 2)
  transform: Translate { y: (1 - Math.min(1, b.rise * 1.4)) * 16 }

  // ── состояние ──
  property real bright: 0.5
  property int disk: 0
  property string shell: ""
  property string hostName: ""
  property string uptime: ""
  property int pkgs: 0
  property string distro: ""
  Process {
    id: sysRead
    command: ["sh", "-c", "brightnessctl -m 2>/dev/null | head -1 | cut -d, -f4; df --output=pcent / | tail -1; basename \"$SHELL\"; " +
      "cat /etc/hostname 2>/dev/null || hostname; uptime -p; pacman -Qq 2>/dev/null | wc -l; . /etc/os-release; echo \"$NAME\""]
    stdout: StdioCollector {
      onStreamFinished: {
        var l = String(text || "").split("\n")
        b.bright = (parseInt(l[0]) || 50) / 100
        b.disk = parseInt(l[1]) || 0
        b.shell = (l[2] || "").trim(); b.hostName = (l[3] || "").trim()
        b.uptime = (l[4] || "").trim().replace(/^up\s+/, "").replace(/ hours?/, "H").replace(/ minutes?/, "M").replace(/,/g, "").toUpperCase()
        b.pkgs = parseInt(l[5]) || 0; b.distro = (l[6] || "").trim()
      }
    }
  }
  onLiveChanged: if (live && !sysRead.running) sysRead.running = true
  Timer { interval: 10000; repeat: true; running: b.live; onTriggered: if (!sysRead.running) sysRead.running = true }
  PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property real vol: sink && sink.audio ? sink.audio.volume : 0
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: b.live; onTriggered: b.now = new Date() }
  readonly property string avatar: { var a = String(host.value("dashAvatar") || "~/.face"); return a.replace(/^~/, Quickshell.env("HOME")) }

  // ── детали: карточка, плитка ──
  component Card: Item {
    id: cc
    default property alias content: ccFace.data
    property real r: 10
    Rectangle { x: 5; y: 5; width: cc.width; height: cc.height; radius: cc.r; color: b.ink }
    Rectangle { id: ccFace; width: cc.width; height: cc.height; radius: cc.r; color: b.card; border.width: 2.5; border.color: b.ink }
  }
  component Tile: Item {
    id: tl
    default property alias content: tlFace.data
    property color fill: b.tileC
    property real r: 7
    property real sh: 3
    property bool hot: false
    signal clicked()
    readonly property real lift: tlTap.pressed ? 0 : tlHov.hovered && hot ? sh + 1 : sh
    Rectangle { x: tl.sh; y: tl.sh; width: tl.width; height: tl.height; radius: tl.r; color: b.ink }
    Rectangle {
      id: tlFace
      x: tl.sh - tl.lift; y: tl.sh - tl.lift
      width: tl.width; height: tl.height; radius: tl.r
      color: tl.fill; border.width: 2; border.color: b.ink
      Behavior on x { NumberAnimation { duration: 90 } }
      Behavior on y { NumberAnimation { duration: 90 } }
    }
    HoverHandler { id: tlHov; enabled: tl.hot; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tlTap; enabled: tl.hot; onTapped: tl.clicked() }
  }
  component Ico: Text { font.family: b.mono; color: b.ink }
  component Lbl: Text { font.family: b.mono; color: b.ink }

  // большая подложка
  Card { anchors.fill: parent; r: 14 }

  // ── 1 колонка ──
  Card {
    x: 20; y: 16; width: 168; height: 190
    Tile {
      x: 46; y: 16; width: 72; height: 72
      fill: "#e8dfcf"
      Image { id: face; anchors.fill: parent; anchors.margins: 3; source: "file://" + b.avatar; fillMode: Image.PreserveAspectCrop; visible: false; layer.enabled: true }
      Rectangle { id: faceMask; anchors.fill: face; radius: 5; visible: false; layer.enabled: true }
      MultiEffect { anchors.fill: face; source: face; visible: face.status === Image.Ready; maskEnabled: true; maskSource: faceMask; maskThresholdMin: 0.5 }
      Lbl { anchors.centerIn: parent; visible: face.status !== Image.Ready; text: (Quickshell.env("USER") || "u").charAt(0).toUpperCase(); font.pixelSize: 28; font.bold: true }
    }
    Lbl { anchors.horizontalCenter: parent.horizontalCenter; y: 100; text: Quickshell.env("USER") || "user"; font.pixelSize: 15 }
    Lbl { anchors.horizontalCenter: parent.horizontalCenter; y: 124; text: (Quickshell.env("USER") || "user") + "@" + (b.hostName || "localhost"); font.pixelSize: 9; color: b.muted }
    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter; y: 148
      width: onl.implicitWidth + 22; height: 20; radius: 10
      color: b.pastel.green; border.width: 1.5; border.color: b.ink
      Row { anchors.centerIn: parent; spacing: 5
        Rectangle { width: 6; height: 6; radius: 3; color: "#3c7a3c"; anchors.verticalCenter: parent.verticalCenter }
        Lbl { id: onl; text: "Online"; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter } }
    }
  }
  Card {
    x: 20; y: 218; width: 168; height: 256
    Column {
      x: 12; y: 12
      spacing: 9
      Repeater {
        model: [["", "#e66000", "Firefox", "omarchy-launch-browser"], ["", "#4a8a3a", "Terminal", "omarchy-launch-terminal"],
                ["", "#d9a441", "Files", "nautilus --new-window"], ["", "#1db954", "Spotify", "omarchy-launch-or-focus spotify"],
                ["", "#3a7bd5", "Editor", "omarchy-launch-editor"], ["", "#7a4ccf", "Discord", "omarchy-launch-or-focus discord"]]
        Tile {
          required property var modelData
          width: 144 - 3; height: 30
          hot: true
          onClicked: { b.host.dashboardOpen = false; Quickshell.execDetached(["bash", "-c", "uwsm-app -- " + modelData[3]]) }
          Row { x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 10
            Ico { text: modelData[0]; color: modelData[1]; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
            Lbl { text: modelData[2]; font.pixelSize: 11; font.bold: true; anchors.verticalCenter: parent.verticalCenter } }
        }
      }
    }
  }

  // ── 2 колонка: часы, погода ──
  Card {
    x: 200; y: 16; width: 250; height: 86
    Row {
      anchors.centerIn: parent
      spacing: 14
      Row {
        anchors.verticalCenter: parent.verticalCenter
        Lbl { text: Qt.formatTime(b.now, "hh:mm AP").split(" ")[0].replace(":", " : "); font.pixelSize: 26 }
        Lbl { text: Qt.formatTime(b.now, "AP"); font.pixelSize: 9; color: b.muted; anchors.bottom: parent.bottom; anchors.bottomMargin: 5 }
      }
      Rectangle { width: 1.5; height: 40; color: Qt.rgba(0, 0, 0, 0.2); anchors.verticalCenter: parent.verticalCenter }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Lbl { text: Qt.formatDate(b.now, "dddd").toUpperCase(); font.pixelSize: 10; font.bold: true }
        Lbl { text: Qt.formatDate(b.now, "MMMM d, yyyy"); font.pixelSize: 9; color: b.muted }
      }
    }
  }
  Card {
    id: wx
    x: 200; y: 114; width: 250; height: 140
    readonly property var w: b.host.weather
    readonly property bool ok: !!w && w.error === undefined && w.temp !== undefined
    readonly property int hour: b.now.getHours()
    readonly property bool night: hour >= 19 || hour < 6
    function desc(c) {
      var t = [[[0], "Clear Sky"], [[1, 2], "Partly Cloudy"], [[3], "Overcast"], [[45, 48], "Fog"], [[51, 53, 55, 56, 57], "Drizzle"],
               [[61, 63, 65, 66, 67, 80, 81, 82], "Rain"], [[71, 73, 75, 77, 85, 86], "Snow"], [[95, 96, 99], "Thunderstorm"]]
      for (var i = 0; i < t.length; i++) if (t[i][0].indexOf(c) !== -1) return t[i][1]
      return ""
    }
    Tile {
      x: 12; y: 12; width: 164; height: 46
      Row { anchors.centerIn: parent; spacing: 10
        Lbl { text: wx.ok ? Math.round(wx.w.temp) + "°C" : "--°C"; font.pixelSize: 19; anchors.verticalCenter: parent.verticalCenter }
        Rectangle { width: 1.5; height: 22; color: Qt.rgba(0, 0, 0, 0.2); anchors.verticalCenter: parent.verticalCenter }
        Lbl { text: wx.ok ? wx.desc(wx.w.code) : "No city"; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter } }
    }
    Tile {
      x: 186; y: 12; width: 48; height: 46
      Ico { anchors.centerIn: parent; text: wx.night ? "\u{F0F65}" : ""; font.pixelSize: 20 }
    }
    Tile {
      x: 12; y: 72; width: 222; height: 52
      Lbl { x: 8; y: 4; text: "“"; font.pixelSize: 14; color: b.pastel.red }
      Lbl {
        x: 22; anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 34
        wrapMode: Text.WordWrap
        font.pixelSize: 9
        text: wx.hour < 6 ? "Late night — the best bugs come out now." : wx.hour < 12 ? "A fresh morning, a fresh build." :
              wx.hour < 18 ? "A slow afternoon, good for refactoring." : "A peaceful evening, perfect for compiling."
      }
    }
  }

  // ── 3 колонка: звук и яркость ──
  Card {
    x: 462; y: 16; width: 92; height: 238
    Row {
      x: 12; y: 14
      spacing: 14
      Repeater {
        model: [["", b.pastel.salmon, "vol"], ["", b.pastel.green, "bright"]]
        Column {
          id: sc
          required property var modelData
          spacing: 10
          readonly property real v: modelData[2] === "vol" ? b.vol : b.bright
          function set(x) {
            x = Math.max(0, Math.min(1, x))
            if (modelData[2] === "vol") { if (b.sink && b.sink.audio) { b.sink.audio.muted = false; b.sink.audio.volume = x } }
            else { b.bright = Math.max(0.02, x); Quickshell.execDetached(["brightnessctl", "-q", "set", Math.round(b.bright * 100) + "%"]) }
          }
          Tile { width: 24; height: 24; fill: sc.modelData[1]; Ico { anchors.centerIn: parent; text: sc.modelData[0]; font.pixelSize: 11 } }
          Item {
            width: 24; height: 126
            Rectangle { anchors.fill: parent; radius: 8; color: b.tileC; border.width: 2; border.color: b.ink }
            Rectangle {
              anchors.bottom: parent.bottom; anchors.bottomMargin: 2; anchors.horizontalCenter: parent.horizontalCenter
              width: parent.width - 4; height: Math.max(8, (parent.height - 4) * sc.v); radius: 6
              color: sc.modelData[1]
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onPressed: function(m) { sc.set(1 - m.y / height) }
              onPositionChanged: function(m) { if (pressed) sc.set(1 - m.y / height) } }
            WheelHandler { onWheel: function(e) { sc.set(sc.v + (e.angleDelta.y > 0 ? 0.05 : -0.05)) } }
          }
          Tile { width: 26; height: 16; r: 4; sh: 2; fill: sc.modelData[1]; Lbl { anchors.centerIn: parent; text: Math.round(sc.v * 100) + "%"; font.pixelSize: 7; font.bold: true } }
        }
      }
    }
  }

  // ── 4 колонка: System Specs ──
  Card {
    x: 566; y: 16; width: 236; height: 238
    Row { x: 14; y: 14; spacing: 7
      Ico { text: ""; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
      Lbl { text: "System Specs"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter } }
    Rectangle { x: 14; y: 40; width: parent.width - 28; height: 1.5; color: Qt.rgba(0, 0, 0, 0.18) }
    Grid {
      x: 12; y: 52
      columns: 2; columnSpacing: 8; rowSpacing: 8
      Repeater {
        model: [["", b.pastel.peach, "OS", b.distro || "Linux"], ["", b.pastel.blue, "WM", "Hyprland"],
                ["", b.pastel.green, "Shell", b.shell || "sh"], ["", b.pastel.salmon, "Host", b.hostName || "localhost"],
                ["", b.pastel.purple, "Uptime", b.uptime || "-"], ["", b.pastel.green, "Packages", String(b.pkgs)]]
        Tile {
          required property var modelData
          width: 101; height: 46
          Rectangle { x: 7; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; radius: 5; color: modelData[1]; border.width: 1.5; border.color: b.ink
            Ico { anchors.centerIn: parent; text: modelData[0]; font.pixelSize: 10 } }
          Column { x: 35; anchors.verticalCenter: parent.verticalCenter; spacing: 1
            Lbl { text: modelData[2]; font.pixelSize: 7; color: b.muted }
            Lbl { text: modelData[3]; font.pixelSize: 9; width: 60; elide: Text.ElideRight } }
        }
      }
    }
  }

  // ── плеер ──
  Card {
    id: pl
    x: 200; y: 266; width: 432; height: 112
    readonly property var p: b.host.player
    Tile {
      x: 12; y: 12; width: 84; height: 84; r: 9
      fill: "#e8dfcf"
      Image { id: cover; anchors.fill: parent; anchors.margins: 3; source: pl.p && pl.p.trackArtUrl ? String(pl.p.trackArtUrl) : ""; fillMode: Image.PreserveAspectCrop; visible: false; layer.enabled: true }
      Rectangle { id: coverMask; anchors.fill: cover; radius: 6; visible: false; layer.enabled: true }
      MultiEffect { anchors.fill: cover; source: cover; visible: cover.status === Image.Ready; maskEnabled: true; maskSource: coverMask; maskThresholdMin: 0.5 }
      Ico { anchors.centerIn: parent; visible: cover.status !== Image.Ready; text: ""; font.pixelSize: 24; color: b.muted }
    }
    Column {
      x: 110; y: 14
      width: parent.width - 124
      spacing: 3
      Lbl { width: parent.width; elide: Text.ElideRight; text: pl.p ? pl.p.trackTitle || "—" : "Nothing playing"; font.pixelSize: 13 }
      Lbl { width: parent.width; elide: Text.ElideRight; text: pl.p ? pl.p.trackArtist || "" : ""; font.pixelSize: 9; color: b.muted }
    }
    // пастельная волна точек (cava)
    Row {
      x: 110; y: 52
      spacing: 2
      Repeater {
        model: 22
        Rectangle {
          required property int index
          readonly property real lv: b.host.levels && b.host.levels.length ? Number(b.host.levels[Math.floor(index * b.host.levels.length / 22)] || 0) : 0
          width: 8; height: 6 + 8 * Math.min(1, lv)
          radius: 4
          anchors.verticalCenter: parent ? parent.verticalCenter : undefined
          color: b.cava[Math.floor(index * b.cava.length / 22)]
          opacity: pl.p && pl.p.isPlaying ? 1 : 0.5
        }
      }
    }
    Lbl {
      x: 110; y: 80
      function mmss(x) { x = Math.max(0, Math.floor(x || 0)); return Math.floor(x / 60) + ":" + ("0" + (x % 60)).slice(-2) }
      text: pl.p ? mmss(pl.p.position) : "0:00"; font.pixelSize: 9
    }
    Lbl {
      anchors.right: parent.right; anchors.rightMargin: 14; y: 80
      function mmss(x) { x = Math.max(0, Math.floor(x || 0)); return Math.floor(x / 60) + ":" + ("0" + (x % 60)).slice(-2) }
      text: pl.p ? mmss(pl.p.length) : "0:00"; font.pixelSize: 9
    }
    Row {
      anchors.horizontalCenter: parent.horizontalCenter; anchors.horizontalCenterOffset: 52
      y: 72
      spacing: 10
      Tile { width: 24; height: 24; hot: true; onClicked: if (pl.p) pl.p.previous(); Ico { anchors.centerIn: parent; text: ""; font.pixelSize: 9 } }
      Tile { width: 30; height: 28; hot: true; fill: b.pastel.salmon; onClicked: if (pl.p) pl.p.togglePlaying()
        Ico { anchors.centerIn: parent; text: pl.p && pl.p.isPlaying ? "" : ""; font.pixelSize: 11 } }
      Tile { width: 24; height: 24; hot: true; onClicked: if (pl.p) pl.p.next(); Ico { anchors.centerIn: parent; text: ""; font.pixelSize: 9 } }
    }
  }

  // ── CPU / RAM / Disk ──
  Card {
    x: 644; y: 266; width: 158; height: 112
    Column {
      x: 10; y: 12
      spacing: 8
      Repeater {
        model: [["", b.pastel.salmon, "CPU", b.host.cpu], ["", b.pastel.blue, "RAM", b.host.mem], ["", b.pastel.green, "Disk", b.disk / 100]]
        Tile {
          required property var modelData
          width: 135; height: 22; sh: 2
          Row { x: 4; anchors.verticalCenter: parent.verticalCenter; spacing: 5
            Rectangle { width: 14; height: 14; radius: 3; color: modelData[1]; border.width: 1.2; border.color: b.ink; anchors.verticalCenter: parent.verticalCenter
              Ico { anchors.centerIn: parent; text: modelData[0]; font.pixelSize: 7 } }
            Lbl { width: 22; text: modelData[2]; font.pixelSize: 8; anchors.verticalCenter: parent.verticalCenter }
            Rectangle { width: 52; height: 7; radius: 3.5; color: b.tileC; border.width: 1.2; border.color: b.ink; anchors.verticalCenter: parent.verticalCenter
              Rectangle { x: 1; y: 1; height: parent.height - 2; radius: 2.5; width: Math.max(0, (parent.width - 2) * Math.min(1, modelData[3])); color: modelData[1] } }
            Lbl { text: Math.round(modelData[3] * 100) + "%"; font.pixelSize: 8; anchors.verticalCenter: parent.verticalCenter } }
        }
      }
    }
  }

  // ── ссылки ──
  Card {
    x: 200; y: 390; width: 602; height: 84
    Row {
      anchors.centerIn: parent
      spacing: 12
      Repeater {
        model: [["", b.pastel.grey, "GitHub", "https://github.com"], ["", b.pastel.salmon, "Reddit", "https://reddit.com"],
                ["", b.pastel.red, "YouTube", "https://youtube.com"], ["", b.pastel.green, "WhatsApp", "https://web.whatsapp.com"],
                ["", b.pastel.pink, "Gmail", "https://mail.google.com"], ["", b.pastel.lavender, "Twitch", "https://twitch.tv"]]
        Tile {
          required property var modelData
          width: 82; height: 52
          hot: true
          fill: modelData[1]
          onClicked: { b.host.dashboardOpen = false; Quickshell.execDetached(["xdg-open", modelData[3]]) }
          Column { anchors.centerIn: parent; spacing: 4
            Ico { anchors.horizontalCenter: parent.horizontalCenter; text: modelData[0]; font.pixelSize: 14 }
            Lbl { anchors.horizontalCenter: parent.horizontalCenter; text: modelData[2]; font.pixelSize: 8; font.bold: true } }
        }
      }
    }
  }
}

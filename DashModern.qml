import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Дашборд Modern — домашний экран на весь экран, по его Modern/home/Home.qml (github.com/elifouts/Dotfiles, GPL-3.0;
// облик — v2/home-default.png): обои под сильным размытием, сверху крупные часы 128 px и «день, число месяц», ниже
// ряд карточек матового стекла — Now Playing (обложка, трек, шкала, ⏮ ⏯ ⏭), календарь месяца, System (кольца CPU /
// Memory / Disk, полосы RAM и температуры, процессор и uptime), Volume (шкала) и Notifications; внизу — кнопки
// сеанса (замок, выход, перезагрузка, выключение). Открывается dashboardOpen при dashStyle modern; Esc / клик мимо —
// закрыть. Опрос системы — пока открыт.
PanelWindow {
  id: win
  required property var host
  readonly property bool on: host.dashboardOpen && String(host.value("dashStyle")) === "modern"

  property real t: 0
  visible: t > 0.001
  screen: host.focusedScreen
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  WlrLayershell.namespace: "omarchy-dashboard"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: on ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  onOnChanged: {
    if (on) { wall.source = ""; wall.source = "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/current/background"; closing.stop(); opening.restart(); sysProbe.running = true }
    else { opening.stop(); closing.restart() }
  }
  NumberAnimation { id: opening; target: win; property: "t"; to: 1; duration: 420; easing.type: Easing.OutCubic }
  NumberAnimation { id: closing; target: win; property: "t"; to: 0; duration: 240; easing.type: Easing.InCubic }
  function close() { host.dashboardOpen = false }

  readonly property color fg: host.foreground
  readonly property color bg: host.background
  readonly property color accent: host.accent
  function a(c, k) { return Qt.rgba(c.r, c.g, c.b, k) }
  readonly property string font: Qt.fontFamilies().indexOf("CodeNewRoman Nerd Font Propo") !== -1 ? "CodeNewRoman Nerd Font Propo"
    : Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : "monospace"
  readonly property real u: Math.min(width / 1920, height / 1080) * 1.15
  function stage(i) { return Math.max(0, Math.min(1, (t - i * 0.08) / (1 - i * 0.08))) }

  // ── данные ──
  SysStats { id: ss; live: win.on }
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: win.on; triggeredOnStart: true; onTriggered: win.now = new Date() }
  property var sys: ({})
  Process {
    id: sysProbe
    command: ["bash", "-c", "echo \"CPUM=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')\";" +
      "awk '/^MemTotal/{print \"MEMT=\"$2} /^MemAvailable/{print \"MEMA=\"$2}' /proc/meminfo; echo \"UP=$(cut -d' ' -f1 /proc/uptime)\";" +
      "echo \"VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)\"; echo \"MSG=$(ls ~/.local/state/omarchy/notifications/history 2>/dev/null | wc -l)\""]
    stdout: StdioCollector {
      onStreamFinished: {
        var o = {}, l = text.split("\n")
        for (var i = 0; i < l.length; i++) { var k = l[i].indexOf("="); if (k > 0) o[l[i].slice(0, k)] = l[i].slice(k + 1) }
        win.sys = o
      }
    }
  }
  Timer { interval: 3000; repeat: true; running: win.on; onTriggered: if (!sysProbe.running) sysProbe.running = true }
  readonly property real volume: { var m = String(sys.VOL || "").match(/([\d.]+)/); return m ? Number(m[1]) : 0 }
  property var notes: []
  Process {
    id: noteProbe
    running: win.on
    command: ["sh", "-c", "for f in $(ls -t ~/.local/state/omarchy/notifications/history 2>/dev/null | head -4); do jq -c '{s: (.summary // .title // \"\"), b: (.body // \"\"), a: (.app // .appName // \"\")}' ~/.local/state/omarchy/notifications/history/$f 2>/dev/null; done"]
    stdout: StdioCollector { onStreamFinished: win.notes = text.trim().split("\n").filter(function(x) { return x }).map(function(x) { try { return JSON.parse(x) } catch (e) { return null } }).filter(function(x) { return x }) }
  }

  // обои под размытием
  Image { id: wall; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; sourceSize.width: 960; asynchronous: true; cache: false; visible: false }
  MultiEffect { anchors.fill: parent; source: wall; opacity: win.t; blurEnabled: true; blur: 1; blurMax: 64; brightness: -0.12 }
  Rectangle { anchors.fill: parent; color: win.a(win.bg, 0.35); opacity: win.t }
  MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: win.close() }
  Item { focus: win.on; Keys.onEscapePressed: win.close() }

  component Card: Rectangle {
    id: card
    property string title: ""
    property int order: 0
    default property alias content: inner.data
    radius: 14 * win.u
    color: win.a(win.bg, 0.6)
    border.width: 1
    border.color: win.a(win.fg, 0.07)
    opacity: win.stage(card.order)
    transform: Translate { y: (1 - win.stage(card.order)) * 24 }
    MouseArea { anchors.fill: parent }
    Text { x: 16 * win.u; y: 14 * win.u; text: card.title; font.family: win.font; font.pixelSize: 12 * win.u; color: win.a(win.fg, 0.55) }
    Item { id: inner; anchors.fill: parent; anchors.margins: 16 * win.u; anchors.topMargin: 40 * win.u }
  }
  component Ring: Item {
    id: rg
    property real v: 0
    property string label: ""
    width: 66 * win.u; height: 92 * win.u
    Shape {
      width: 66 * win.u; height: 66 * win.u
      preferredRendererType: Shape.CurveRenderer
      ShapePath { strokeWidth: 5 * win.u; strokeColor: win.a(win.fg, 0.1); fillColor: "transparent"; capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: 33 * win.u; centerY: 33 * win.u; radiusX: 28 * win.u; radiusY: 28 * win.u; startAngle: -90; sweepAngle: 360 } }
      ShapePath { strokeWidth: 5 * win.u; strokeColor: win.accent; fillColor: "transparent"; capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: 33 * win.u; centerY: 33 * win.u; radiusX: 28 * win.u; radiusY: 28 * win.u; startAngle: -90; sweepAngle: 359.9 * Math.max(0.001, Math.min(1, rg.v)) } }
      Text { anchors.centerIn: parent; text: Math.round(rg.v * 100) + "%"; font.family: win.font; font.pixelSize: 14 * win.u; color: win.fg }
    }
    Text { y: 72 * win.u; anchors.horizontalCenter: parent.horizontalCenter; text: rg.label; font.family: win.font; font.pixelSize: 12 * win.u; color: win.a(win.fg, 0.6) }
  }
  component Btn: Rectangle {
    id: b
    property string glyph: ""
    signal hit()
    width: 64 * win.u; height: 64 * win.u; radius: 20 * win.u
    color: ba.containsMouse ? win.a(win.fg, 0.16) : win.a(win.bg, 0.6)
    border.width: 1; border.color: win.a(win.fg, 0.07)
    Text { anchors.centerIn: parent; text: b.glyph; font.family: win.font; font.pixelSize: 24 * win.u; color: win.fg }
    MouseArea { id: ba; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.hit() }
  }

  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    y: parent.height * 0.08
    spacing: 2 * win.u
    opacity: win.stage(0)
    Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(win.now, "hh:mm"); font.family: win.font; font.pixelSize: 128 * win.u; font.bold: true; color: win.fg }
    Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(win.now, "dddd, d MMMM"); font.family: win.font; font.pixelSize: 22 * win.u; color: win.a(win.fg, 0.8) }
  }

  Row {
    id: cards
    anchors.horizontalCenter: parent.horizontalCenter
    y: parent.height * 0.36
    spacing: 20 * win.u

    // Now Playing
    Card {
      title: "Now Playing"; order: 1
      width: 360 * win.u; height: 350 * win.u
      readonly property var p: win.host.player
      Column {
        width: parent.width
        spacing: 14 * win.u
        Row {
          spacing: 14 * win.u
          Rectangle {
            width: 100 * win.u; height: 100 * win.u; radius: 18 * win.u; color: win.a(win.fg, 0.08); clip: true
            Image { anchors.fill: parent; source: win.host.player && win.host.player.trackArtUrl ? win.host.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 200 }
          }
          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: 190 * win.u
            spacing: 4 * win.u
            Text { width: parent.width; elide: Text.ElideRight; text: win.host.player ? (win.host.player.trackTitle || "") : "Nothing playing"; font.family: win.font; font.pixelSize: 17 * win.u; color: win.fg }
            Text { width: parent.width; elide: Text.ElideRight; text: win.host.player ? (win.host.player.trackArtist || "") : ""; font.family: win.font; font.pixelSize: 13 * win.u; color: win.a(win.fg, 0.6) }
          }
        }
        Rectangle {
          width: parent.width; height: 4 * win.u; radius: 2 * win.u; color: win.a(win.fg, 0.12)
          Rectangle { height: parent.height; radius: parent.radius; color: win.fg
            width: win.host.player && win.host.player.length > 0 ? parent.width * Math.min(1, win.host.player.position / win.host.player.length) : 0 }
        }
        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: 28 * win.u
          Repeater {
            model: [["󰒮", 0], [win.host.player && win.host.player.isPlaying ? "󰏤" : "󰐊", 1], ["󰒭", 2]]
            Text {
              required property var modelData
              text: modelData[0]; font.family: win.font; font.pixelSize: (modelData[1] === 1 ? 34 : 24) * win.u; color: win.fg
              MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor
                onClicked: { var q = win.host.player; if (!q) return; if (parent.modelData[1] === 0) q.previous(); else if (parent.modelData[1] === 1) q.togglePlaying(); else q.next() } }
            }
          }
        }
      }
    }

    // календарь
    Card {
      id: calCard
      title: Qt.formatDate(win.now, "MMMM yyyy"); order: 2
      width: 340 * win.u; height: 350 * win.u
      readonly property int first: (new Date(win.now.getFullYear(), win.now.getMonth(), 1).getDay() + 6) % 7
      readonly property int days: new Date(win.now.getFullYear(), win.now.getMonth() + 1, 0).getDate()
      Grid {
        columns: 7
        width: parent.width
        Repeater { model: ["M", "T", "W", "T", "F", "S", "S"]; Text { required property string modelData; width: calCard.width / 7 - 5 * win.u; height: 26 * win.u; horizontalAlignment: Text.AlignHCenter; text: modelData; font.family: win.font; font.pixelSize: 12 * win.u; color: win.a(win.fg, 0.45) } }
        Repeater {
          model: 42
          Item {
            required property int index
            readonly property int day: index - calCard.first + 1
            readonly property bool today: day === win.now.getDate()
            width: calCard.width / 7 - 5 * win.u; height: 33 * win.u
            Rectangle { anchors.centerIn: parent; width: 28 * win.u; height: width; radius: width / 2; color: parent.today ? win.accent : "transparent" }
            Text { anchors.centerIn: parent; text: parent.day >= 1 && parent.day <= calCard.days ? String(parent.day) : ""; font.family: win.font; font.pixelSize: 14 * win.u; color: parent.today ? win.bg : win.fg }
          }
        }
      }
    }

    // система
    Card {
      title: "System"; order: 3
      width: 380 * win.u; height: 350 * win.u
      Column {
        width: parent.width
        spacing: 16 * win.u
        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: 24 * win.u
          Ring { v: ss.cpu; label: "CPU" }
          Ring { v: ss.mem; label: "Memory" }
          Ring { v: ss.disk; label: "Disk" }
        }
        Row {
          spacing: 10 * win.u
          Repeater {
            model: [["RAM", ss.mem, ((Number(win.sys.MEMT || 0) - Number(win.sys.MEMA || 0)) / 1048576).toFixed(1) + " / " + (Number(win.sys.MEMT || 0) / 1048576).toFixed(0) + " GB"],
              ["TEMP", ss.temp, Math.round(ss.temp * 100) + "°C"]]
            Rectangle {
              required property var modelData
              width: 168 * win.u; height: 52 * win.u; radius: 10 * win.u; color: win.a(win.fg, 0.06)
              Text { x: 10 * win.u; y: 8 * win.u; text: parent.modelData[0] + "   " + parent.modelData[2]; font.family: win.font; font.pixelSize: 10 * win.u; color: win.a(win.fg, 0.6) }
              Rectangle { x: 10 * win.u; y: 30 * win.u; width: parent.width - 20 * win.u; height: 4 * win.u; radius: 2 * win.u; color: win.a(win.fg, 0.12)
                Rectangle { height: parent.height; radius: parent.radius; color: win.accent; width: parent.width * Math.min(1, parent.parent.modelData[1]) } }
            }
          }
        }
        Text { width: parent.width; elide: Text.ElideRight; text: win.sys.CPUM || ""; font.family: win.font; font.pixelSize: 11 * win.u; color: win.a(win.fg, 0.6) }
        Text {
          text: { var s = parseFloat(win.sys.UP || 0); return "Up " + Math.floor(s / 3600) + "h " + Math.floor(s % 3600 / 60) + "m" }
          font.family: win.font; font.pixelSize: 11 * win.u; color: win.a(win.fg, 0.6)
        }
      }
    }

    // громкость и уведомления
    Column {
      spacing: 20 * win.u
      Card {
        title: "Volume"; order: 4
        width: 340 * win.u; height: 90 * win.u
        Text { anchors.right: parent.right; y: -26 * win.u; text: Math.round(win.volume * 100) + "%"; font.family: win.font; font.pixelSize: 12 * win.u; color: win.a(win.fg, 0.6) }
        Rectangle {
          width: parent.width; height: 26 * win.u; radius: 13 * win.u; color: win.a(win.fg, 0.1)
          Rectangle { height: parent.height; radius: parent.radius; color: win.fg; width: Math.max(height, parent.width * Math.min(1, win.volume)) }
          Text { x: 10 * win.u; anchors.verticalCenter: parent.verticalCenter; text: "󰕾"; font.family: win.font; font.pixelSize: 13 * win.u; color: win.bg }
          MouseArea {
            anchors.fill: parent
            function set(mx) { var v = Math.max(0, Math.min(1, mx / width)); Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", v.toFixed(2)]); win.sys = Object.assign({}, win.sys, { VOL: "Volume: " + v.toFixed(2) }) }
            onPressed: function(m) { set(m.x) }
            onPositionChanged: function(m) { if (pressed) set(m.x) }
          }
        }
      }
      Card {
        title: "Notifications  ·  " + (win.sys.MSG || 0); order: 5
        width: 340 * win.u; height: 240 * win.u
        Column {
          width: parent.width
          spacing: 8 * win.u
          Repeater {
            model: win.notes.slice(0, 3)
            Rectangle {
              required property var modelData
              width: parent.width; height: 52 * win.u; radius: 10 * win.u; color: win.a(win.fg, 0.06)
              Column {
                x: 12 * win.u; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 24 * win.u
                Text { width: parent.width; elide: Text.ElideRight; text: parent.parent.modelData.s; font.family: win.font; font.pixelSize: 12 * win.u; font.bold: true; color: win.fg }
                Text { width: parent.width; elide: Text.ElideRight; text: parent.parent.modelData.b || parent.parent.modelData.a; font.family: win.font; font.pixelSize: 11 * win.u; color: win.a(win.fg, 0.6) }
              }
            }
          }
        }
      }
    }
  }

  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: parent.height * 0.1
    spacing: 12 * win.u
    opacity: win.stage(6)
    Btn { glyph: "󰌾"; onHit: { win.close(); Quickshell.execDetached(["omarchy-lock-screen"]) } }
    Btn { glyph: "󰍃"; onHit: { win.close(); Quickshell.execDetached(["omarchy-system", "logout"]) } }
    Btn { glyph: "󰜉"; onHit: { win.close(); Quickshell.execDetached(["omarchy-system", "reboot"]) } }
    Btn { glyph: "⏻"; onHit: { win.close(); Quickshell.execDetached(["omarchy-system", "shutdown"]) } }
  }
}

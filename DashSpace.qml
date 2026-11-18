import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower

// Дашборд Space — визор HUD (по мотивам стиля Space из elifouts/Dotfiles, GPL-3.0 — его Space/home/Home.qml,
// common/Controls.qml). 860 × 540: по углам уголки 40 px акцентом, сверху часы HH:MM:SS тонким шрифтом и строка
// «день · дата · N окон · up …»; слева плашки HOST (os / kernel / user), PROCESSOR (модель, шкала, температура),
// MEMORY (шкала, занято), справа GRAPHICS (если есть видеокарта), LINK (сеть, громкость, батарея) и NOW PLAYING
// (обложка, трек, ⏮ ⏯ ⏭, перемотка штрихами). Плашка — срезанный угол 14 px, рамка акцентом 35 %, черта 2 px акцентом
// с внешней стороны, плашки въезжают сбоку по очереди. Подписи капсом вразрядку «расшифровываются» (SpaceDecode).
// full — на весь экран, как его Home (space/home.png): уголки в углах экрана, часы по центру сверху, плашки — колонками
// у левого и правого края (окно — DashSpaceFull.qml).
Item {
  id: sp
  required property var host
  property real rise: 1
  property bool full: false
  readonly property bool live: rise > 0.01
  width: 860
  height: 540
  readonly property real edge: full ? Math.round(width * 0.055) : 0      // отступ колонок от края
  readonly property real colY: full ? Math.round(height * 0.17) : 112   // верх колонок
  readonly property real cornerIn: full ? 20 : 0                         // уголки — от края экрана

  readonly property color fg: host.foreground
  readonly property color bg: host.background
  readonly property color acc: host.accent
  function a(c, k) { return Qt.rgba(c.r, c.g, c.b, k) }
  readonly property string mono: Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : host.fontFamily
  function stage(i) { return Math.max(0, Math.min(1, (rise - i * 0.07) / (1 - i * 0.07))) }

  SurfState { id: st; live: sp.live }
  SysStats { id: ss; live: sp.live }
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: sp.live; triggeredOnStart: true; onTriggered: sp.now = new Date() }

  // неизменное о системе: имя, ОС, ядро, процессор, видеокарта, память, uptime
  property var sys: ({})
  Process {
    id: sysProbe
    command: ["bash", "-c", "echo \"HOST=$(cat /etc/hostname 2>/dev/null || hostname)\"; . /etc/os-release 2>/dev/null; echo \"OS=$PRETTY_NAME\";" +
      "echo \"KERN=$(uname -r)\"; echo \"CPUM=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')\";" +
      "echo \"GPU=$(lspci 2>/dev/null | grep -m1 -E 'VGA|3D' | sed 's/.*: //; s/ (rev.*//')\";" +
      "echo \"MEMT=$(awk '/^MemTotal/{print $2}' /proc/meminfo)\"; echo \"UP=$(cut -d' ' -f1 /proc/uptime)\""]
    stdout: StdioCollector {
      onStreamFinished: {
        var o = {}, lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) { var k = lines[i].indexOf("="); if (k > 0) o[lines[i].slice(0, k)] = lines[i].slice(k + 1) }
        sp.sys = o
      }
    }
  }
  onLiveChanged: if (live && !sysProbe.running) sysProbe.running = true
  Component.onCompleted: sysProbe.running = true
  function uptime(sec) {
    var h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60)
    return h > 0 ? h + "h " + m + "m" : m + "m"
  }
  function gb(kb) { return (kb / 1048576).toFixed(1) }
  readonly property real memTotal: Number(sys.MEMT || 0)
  readonly property var battery: UPower.displayDevice
  readonly property bool hasBattery: !!battery && battery.isLaptopBattery

  // ── уголки визора ──
  Repeater {
    model: 4
    Item {
      required property int index
      readonly property bool r: index % 2 === 1
      readonly property bool b: index > 1
      readonly property real inset: 30 * (1 - sp.rise)
      x: r ? sp.width - 40 - inset - sp.cornerIn : inset + sp.cornerIn
      y: b ? sp.height - 40 - inset - sp.cornerIn : inset + sp.cornerIn
      width: 40; height: 40
      opacity: sp.rise
      Rectangle { width: 40; height: 2; y: parent.b ? 38 : 0; color: sp.acc }
      Rectangle { width: 2; height: 40; x: parent.r ? 38 : 0; color: sp.acc }
    }
  }

  // ── часы ──
  Column {
    anchors.horizontalCenter: parent.horizontalCenter
    y: sp.full ? Math.round(sp.height * 0.07) : 26
    spacing: 2
    opacity: sp.rise
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: Qt.formatTime(sp.now, "HH:mm:ss")
      font.family: sp.mono; font.pixelSize: 34; font.weight: Font.ExtraLight; font.letterSpacing: 4
      color: sp.fg
    }
    SpaceDecode {
      anchors.horizontalCenter: parent.horizontalCenter
      family: sp.mono
      text: Qt.formatDate(sp.now, "dddd · dd MMMM") + "  ·  " + Hyprland.toplevels.values.length + " windows  ·  up " + sp.uptime(Number(sp.sys.UP || 0))
      color: sp.a(sp.fg, 0.45)
    }
  }

  // ── части ──
  component Plate: Shape {
    id: plate
    property real cut: 14
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeWidth: 1
      strokeColor: sp.a(sp.acc, 0.35)
      fillColor: sp.a(sp.bg, 0.55)
      startX: plate.cut; startY: 0
      PathLine { x: plate.width; y: 0 }
      PathLine { x: plate.width; y: plate.height }
      PathLine { x: 0; y: plate.height }
      PathLine { x: 0; y: plate.cut }
      PathLine { x: plate.cut; y: 0 }
    }
  }
  component Block: Item {
    id: block
    property int order: 0
    property int side: -1
    property string glyph
    property string title
    default property alias content: col.data
    readonly property real k: sp.stage(order)
    width: 320
    height: col.height + 50
    opacity: k
    transform: Translate { x: block.side * 50 * (1 - block.k) }
    Plate { anchors.fill: parent }
    Rectangle { x: block.side < 0 ? 0 : parent.width - 2; y: 14; width: 2; height: parent.height - 14; color: sp.acc }
    Item {
      x: 16; y: 10; width: parent.width - 32; height: 24
      Text { id: tg; text: block.glyph; font.family: sp.mono; font.pixelSize: 14; color: sp.acc; anchors.verticalCenter: parent.verticalCenter }
      SpaceDecode { x: tg.width + 8; height: parent.height; family: sp.mono; text: block.title; color: sp.fg }
      Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: sp.a(sp.acc, 0.25) }
    }
    Column { id: col; x: 16; y: 42; width: parent.width - 32; spacing: 5 }
  }
  component Read: Item {
    property string k
    property string v
    width: parent ? parent.width : 280
    height: 17
    SpaceDecode { text: parent.k; height: parent.height; family: sp.mono; color: sp.a(sp.fg, 0.45) }
    Text {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 90
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideLeft
      text: parent.v
      font.family: sp.mono; font.pixelSize: 12
      color: sp.fg
    }
  }
  // шкала из клеток, как его Slider (cells); moved — двигается мышью / колесом
  component Meter: Item {
    id: mt
    property real value: 0
    property string glyph
    property bool dim: false
    property bool adjustable: false
    property real kbdStep: 0.05
    signal moved(real v)
    function kbdAdjust(d) { if (adjustable) mt.moved(Math.max(0, Math.min(1, value + d * kbdStep))) }
    width: parent ? parent.width : 280
    height: 22
    Text { id: mg; text: mt.glyph; width: 20; font.family: sp.mono; font.pixelSize: 13; color: mt.dim ? sp.a(sp.fg, 0.4) : sp.acc; anchors.verticalCenter: parent.verticalCenter }
    Row {
      id: cells
      x: 26
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2
      readonly property int n: 22
      readonly property real cw: (mt.width - 26 - 40 - (n - 1) * 2) / n
      Repeater {
        model: cells.n
        Rectangle {
          required property int index
          width: cells.cw; height: 8
          color: index < Math.round(Math.min(1, mt.value) * cells.n) ? (mt.dim ? sp.a(sp.fg, 0.3) : sp.acc) : sp.a(sp.fg, 0.12)
        }
      }
    }
    Text {
      anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
      text: Math.round(mt.value * 100)
      font.family: sp.mono; font.pixelSize: 11; color: sp.fg
    }
    MouseArea {
      enabled: mt.adjustable
      x: cells.x; width: cells.width; height: parent.height
      cursorShape: Qt.PointingHandCursor
      onPressed: function(m) { mt.moved(Math.max(0, Math.min(1, m.x / width))) }
      onPositionChanged: function(m) { if (pressed) mt.moved(Math.max(0, Math.min(1, m.x / width))) }
      onWheel: function(w) { mt.moved(Math.max(0, Math.min(1, mt.value + (w.angleDelta.y > 0 ? 0.05 : -0.05)))) }
    }
  }
  component Btn: Rectangle {
    id: bt
    property string glyph
    property bool big: false
    signal hit()
    width: big ? 40 : 30; height: big ? 40 : 30
    color: big ? sp.a(sp.acc, h.hovered ? 0.3 : 0.15) : (h.hovered ? sp.a(sp.acc, 0.12) : "transparent")
    border.width: big ? 1 : 0
    border.color: sp.a(sp.acc, 0.5)
    Text { anchors.centerIn: parent; text: bt.glyph; font.family: sp.mono; font.pixelSize: bt.big ? 16 : 13; color: sp.fg }
    HoverHandler { id: h; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: bt.hit() }
  }

  // ── слева ──
  Column {
    x: sp.edge
    y: sp.colY
    spacing: 14
    Block {
      order: 0; glyph: "󰒋"; title: sp.sys.HOST || "system"
      Read { k: "os"; v: sp.sys.OS || "" }
      Read { k: "kernel"; v: sp.sys.KERN || "" }
      Read { k: "user"; v: Quickshell.env("USER") || "" }
    }
    Block {
      order: 1; glyph: "󰍛"; title: "processor"
      Read { k: "model"; v: sp.sys.CPUM || "" }
      Meter { glyph: "󰓅"; value: ss.cpu }
      Read { k: "temp"; v: Math.round(ss.temp * 100) + "°" }
    }
    Block {
      order: 2; glyph: "󰘚"; title: "memory"
      Meter { glyph: "󰍛"; value: ss.mem }
      Read { k: "used"; v: sp.gb(ss.mem * sp.memTotal) + " / " + sp.gb(sp.memTotal) + " GB" }
    }
  }

  // ── справа ──
  Column {
    x: sp.width - 320 - sp.edge
    y: sp.colY
    spacing: 14
    Block {
      visible: (sp.sys.GPU || "") !== ""
      side: 1; order: 0; glyph: "󰢮"; title: "graphics"
      Read { k: "card"; v: sp.sys.GPU || "" }
    }
    Block {
      side: 1; order: 1; glyph: st.wifi ? "󰤨" : "󰤭"; title: "link"
      Read { k: "network"; v: st.ssid !== "" ? st.ssid : (st.wifi ? "—" : "offline") }
      Meter {
        glyph: st.muted ? "󰝟" : st.vol <= 0.5 ? "󰖀" : "󰕾"
        value: st.vol
        dim: st.muted
        adjustable: true
        onMoved: function(v) { st.setVol(v) }
      }
      Meter {
        visible: sp.hasBattery
        glyph: sp.hasBattery && sp.battery.state === UPowerDeviceState.Charging ? "󰂄" : "󰁹"
        value: sp.hasBattery ? sp.battery.percentage : 0
      }
    }
    Block {
      side: 1; order: 2; glyph: "󰎈"; title: "now playing"
      Item {
        width: parent.width
        height: 64
        Rectangle {
          id: art
          width: 54; height: 54
          color: sp.a(sp.fg, 0.08)
          border.width: 1; border.color: sp.a(sp.acc, 0.35)
          Image {
            anchors.fill: parent; anchors.margins: 1
            source: sp.host.player && sp.host.player.trackArtUrl ? sp.host.player.trackArtUrl : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
          }
        }
        Column {
          x: 66; width: parent.width - 66
          spacing: 3
          SpaceDecode { width: parent.width; family: sp.mono; size: 9; color: sp.a(sp.fg, 0.45); text: sp.host.player ? (sp.host.player.identity || "") : "" }
          Text { width: parent.width; elide: Text.ElideRight; font.family: sp.mono; font.pixelSize: 13; color: sp.fg; text: sp.host.player ? (sp.host.player.trackTitle || "") : "silence" }
          Text { width: parent.width; elide: Text.ElideRight; font.family: sp.mono; font.pixelSize: 11; color: sp.a(sp.fg, 0.6); text: sp.host.player ? (sp.host.player.trackArtist || "") : "nothing playing" }
        }
      }
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 14
        Btn { glyph: "󰒮"; anchors.verticalCenter: parent.verticalCenter; onHit: { var p = sp.host.player; if (p && p.canGoPrevious) p.previous() } }
        Btn { glyph: sp.host.player && sp.host.player.isPlaying ? "󰏤" : "󰐊"; big: true; onHit: { var p = sp.host.player; if (p && p.canTogglePlaying) p.togglePlaying() } }
        Btn { glyph: "󰒭"; anchors.verticalCenter: parent.verticalCenter; onHit: { var p = sp.host.player; if (p && p.canGoNext) p.next() } }
      }
      // перемотка — штрихи, как у него
      Item {
        id: seek
        width: parent.width
        height: 14
        readonly property var p: sp.host.player
        readonly property real frac: p && p.length > 0 ? Math.min(1, p.position / p.length) : 0
        Timer { interval: 1000; repeat: true; running: sp.live && !!seek.p && seek.p.isPlaying; onTriggered: if (seek.p) seek.p.positionChanged() }
        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 3
          Repeater {
            model: 64
            Rectangle {
              required property int index
              width: 1; height: index % 8 === 0 ? 8 : 4
              anchors.verticalCenter: parent ? parent.verticalCenter : undefined
              color: index / 64 < seek.frac ? sp.acc : sp.a(sp.fg, 0.25)
            }
          }
        }
      }
    }
  }
}

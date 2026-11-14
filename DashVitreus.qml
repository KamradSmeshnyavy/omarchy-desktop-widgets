import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire

// Дашборд «из воды» (dashStyle: "vitreus", по мотивам natepayn3/Vitreus, MIT; код свой). Слева — два «карандашных»
// ползунка (громкость, яркость), справа — плитки: часы и дата, погода, плеер (две клетки), переключатели (Wi-Fi,
// Bluetooth, микрофон, ночной свет), система (графики), сеть (зеркальный график приёма / отдачи), хост (аптайм,
// батарея). Плитки всплывают по очереди снизу, как из воды (rise 0 → 1), вдоль кромки у бара бежит волна.
Item {
  id: v

  required property var host
  property real rise: 0                 // 0 — под водой, 1 — всплыли
  property string edge: "top"           // где бар: волна бежит по этой кромке
  readonly property color fg: host.foreground
  readonly property color acc: host.accent
  readonly property string font: host.fontFamily

  readonly property int tileW: 200
  readonly property int tileH: 168
  readonly property int gap: 12
  readonly property int sliderW: 64
  implicitWidth: sliderW + gap + 4 * tileW + 3 * gap
  implicitHeight: 2 * tileH + gap

  // ── громкость и яркость ────────────────────────────────────────────
  PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  property real bright: 0.5
  Process {
    id: brRead
    command: ["brightnessctl", "-m"]
    stdout: StdioCollector { onStreamFinished: { var f = text.split(","); if (f.length > 3) v.bright = Math.max(0, Math.min(1, parseFloat(f[3]) / 100)) } }
  }
  onRiseChanged: if (rise > 0.99 && !brRead.running) brRead.running = true
  function setBright(x) { v.bright = x; Quickshell.execDetached(["brightnessctl", "-q", "set", Math.round(x * 100) + "%"]) }

  // ползунок-карандаш: деревянный корпус, графит на конце, заточка — уровень
  component Pencil: Item {
    id: pen
    property real value: 0
    property string icon: ""
    signal moved(real x)
    width: v.sliderW; height: v.implicitHeight
    readonly property real head: 30
    readonly property real len: height - head - 34
    Rectangle {   // жёлоб
      x: (pen.width - 22) / 2; y: pen.head; width: 22; height: pen.len; radius: 11
      color: Qt.rgba(v.fg.r, v.fg.g, v.fg.b, 0.07)
      border.width: 1; border.color: Qt.rgba(v.fg.r, v.fg.g, v.fg.b, 0.1)
    }
    // корпус от низа до уровня
    Item {
      x: (pen.width - 16) / 2; width: 16
      y: pen.head + pen.len * (1 - pen.value); height: pen.len * pen.value
      clip: true
      Rectangle { anchors.fill: parent; anchors.topMargin: 14; color: v.acc; radius: 3
        Rectangle { x: 4; width: 1.6; height: parent.height; color: Qt.rgba(1, 1, 1, 0.35) }
        Rectangle { x: 10; width: 1.2; height: parent.height; color: Qt.rgba(0, 0, 0, 0.18) } }
      // заточка и грифель
      Shape {
        width: 16; height: 14
        preferredRendererType: Shape.CurveRenderer
        ShapePath { fillColor: "#e8c99a"; strokeWidth: -1
          PathMove { x: 0; y: 14 } PathLine { x: 8; y: 0 } PathLine { x: 16; y: 14 } }
        ShapePath { fillColor: Qt.rgba(v.fg.r, v.fg.g, v.fg.b, 0.9); strokeWidth: -1
          PathMove { x: 5.2; y: 5 } PathLine { x: 8; y: 0 } PathLine { x: 10.8; y: 5 } }
      }
    }
    Text { anchors.horizontalCenter: parent.horizontalCenter; y: 4; text: pen.icon; color: v.fg; opacity: 0.8; font.family: v.host.iconFamily; font.pixelSize: 16 }
    Text { anchors.horizontalCenter: parent.horizontalCenter; y: pen.head + pen.len + 8; text: Math.round(pen.value * 100); color: v.fg; opacity: 0.7; font.family: v.font; font.pixelSize: 12; font.weight: Font.DemiBold }
    MouseArea {
      x: 0; y: pen.head - 6; width: pen.width; height: pen.len + 12
      cursorShape: Qt.PointingHandCursor
      function at(my) { return Math.max(0, Math.min(1, 1 - (my - 6) / pen.len)) }
      onPressed: function(m) { pen.moved(at(m.y)) }
      onPositionChanged: function(m) { if (pressed) pen.moved(at(m.y)) }
      onWheel: function(w) { pen.moved(Math.max(0, Math.min(1, pen.value + (w.angleDelta.y > 0 ? 0.05 : -0.05)))) }
    }
  }
  // ── плитки ─────────────────────────────────────────────────────────
  // плитка всплывает со своей задержкой (i): из-под «воды» снизу вверх, с лёгким перелётом
  component Tile: Rectangle {
    id: tile
    property int i: 0
    property int col: 0
    property int row: 0
    property int span: 1
    readonly property real k: Math.max(0, Math.min(1, v.rise * 1.9 - i * 0.12))
    readonly property real ease: k === 1 ? 1 : 1 - Math.pow(1 - k, 3) * (1 - 1.6 * k * (1 - k))
    x: v.sliderW + v.gap + col * (v.tileW + v.gap)
    y: row * (v.tileH + v.gap) + (1 - ease) * 46
    width: span * v.tileW + (span - 1) * v.gap
    height: v.tileH
    opacity: Math.min(1, k * 1.6)
    radius: 16
    color: Qt.rgba(v.fg.r, v.fg.g, v.fg.b, 0.06)
    border.width: 1; border.color: Qt.rgba(v.fg.r, v.fg.g, v.fg.b, 0.08)
    clip: true
  }
  component Cap: Text {
    color: v.fg; opacity: 0.55
    font.family: v.font; font.pixelSize: 10; font.weight: Font.DemiBold; font.letterSpacing: 1.2
  }

  // громкость и яркость — два узких карандаша в левой колонке
  Item {
    x: 0; width: v.sliderW; height: v.implicitHeight
    opacity: Math.min(1, v.rise * 3)
    Row {
      anchors.fill: parent
      Item { width: parent.width / 2; height: parent.height
        Pencil { anchors.horizontalCenter: parent.horizontalCenter; width: 34
          icon: v.sink && v.sink.audio && v.sink.audio.muted ? "󰝟" : "󰕾"
          value: v.sink && v.sink.audio ? Math.min(1, v.sink.audio.volume) : 0
          onMoved: function(x) { if (v.sink && v.sink.audio) v.sink.audio.volume = x } } }
      Item { width: parent.width / 2; height: parent.height
        Pencil { anchors.horizontalCenter: parent.horizontalCenter; width: 34
          icon: "󰃟"; value: v.bright
          onMoved: function(x) { v.setBright(x) } } }
    }
  }

  // 1. часы и дата
  Tile {
    i: 0; col: 0; row: 0
    SystemClock { id: clk; precision: SystemClock.Minutes }
    Cap { x: 16; y: 14; text: Qt.locale().toString(clk.date, "dddd").toUpperCase() }
    Text { x: 14; y: 34; text: Qt.formatTime(clk.date, "HH:mm"); color: v.fg; font.family: v.font; font.pixelSize: 52; font.weight: Font.Bold }
    Text { x: 16; y: 104; text: Qt.locale().toString(clk.date, "d MMMM"); color: v.acc; font.family: v.font; font.pixelSize: 16; font.weight: Font.DemiBold }
    // ISO-неделя (у Qt.formatDate кода недели нет)
    function isoWeek(d) {
      var t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
      var day = t.getUTCDay() || 7
      t.setUTCDate(t.getUTCDate() + 4 - day)
      return Math.ceil(((t - Date.UTC(t.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7)
    }
    Text { x: 16; y: 128; text: Qt.formatDate(clk.date, "yyyy") + " · W" + parent.isoWeek(clk.date); color: v.fg; opacity: 0.55; font.family: v.font; font.pixelSize: 12 }
  }
  // 2. погода
  Tile {
    i: 1; col: 1; row: 0
    color: "transparent"; border.width: 0
    DashWeather { anchors.fill: parent; host: v.host }
  }
  // 3. плеер — две клетки
  Tile {
    i: 2; col: 2; row: 0; span: 2
    color: "transparent"; border.width: 0
    DashMedia { anchors.fill: parent; host: v.host }
  }
  // 4. переключатели
  Tile {
    id: ctl
    i: 3; col: 0; row: 1
    Cap { x: 16; y: 14; text: "CONTROLS" }
    property bool wifi: true
    Process {
      id: wifiRead
      command: ["nmcli", "radio", "wifi"]
      running: v.rise > 0.99
      stdout: StdioCollector { onStreamFinished: ctl.wifi = text.trim() === "enabled" }
    }
    readonly property var adapter: Bluetooth.defaultAdapter
    Grid {
      x: 14; y: 38; columns: 2; spacing: 10
      Repeater {
        model: [
          { id: "wifi", icon: "󰖩", label: "Wi-Fi" },
          { id: "bt", icon: "󰂯", label: "BT" },
          { id: "mic", icon: "󰍬", label: "Mic" },
          { id: "night", icon: "󰖔", label: "Night" }
        ]
        Rectangle {
          id: tg
          required property var modelData
          readonly property var t: ctl
          readonly property bool on: modelData.id === "wifi" ? t.wifi
            : modelData.id === "bt" ? !!t.adapter && t.adapter.enabled
            : modelData.id === "mic" ? !!v.source && !!v.source.audio && !v.source.audio.muted : false
          width: 80; height: 52; radius: 14
          color: on ? v.acc : Qt.rgba(v.fg.r, v.fg.g, v.fg.b, tgArea.containsMouse ? 0.12 : 0.07)
          Behavior on color { ColorAnimation { duration: 160 } }
          Text { x: 10; y: 8; text: tg.modelData.icon; color: tg.on ? v.host.background : v.fg; font.family: v.host.iconFamily; font.pixelSize: 17 }
          Text { x: 10; y: 30; text: tg.modelData.label; color: tg.on ? v.host.background : v.fg; opacity: 0.85; font.family: v.font; font.pixelSize: 11; font.weight: Font.DemiBold }
          MouseArea {
            id: tgArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var id = tg.modelData.id
              if (id === "wifi") { Quickshell.execDetached(["nmcli", "radio", "wifi", tg.on ? "off" : "on"]); tg.t.wifi = !tg.on }
              else if (id === "bt" && tg.t.adapter) tg.t.adapter.enabled = !tg.t.adapter.enabled
              else if (id === "mic" && v.source && v.source.audio) v.source.audio.muted = !v.source.audio.muted
              else if (id === "night") Quickshell.execDetached(["omarchy-toggle-nightlight"])
            }
          }
        }
      }
    }
  }
  // 5. система
  Tile {
    i: 4; col: 1; row: 1
    color: "transparent"; border.width: 0
    DashStats { anchors.fill: parent; host: v.host }
  }
  // 6. сеть — зеркальный график приёма / отдачи
  Tile {
    i: 5; col: 2; row: 1
    Cap { x: 16; y: 14; text: "NETWORK" }
    function fmt(b) { return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB/s" : b >= 1024 ? Math.round(b / 1024) + " KB/s" : Math.round(b) + " B/s" }
    Text { x: 16; y: 32; text: "↓ " + parent.fmt(v.host.rxRate); color: v.acc; font.family: v.font; font.pixelSize: 13; font.weight: Font.DemiBold }
    Text { x: 108; y: 32; text: "↑ " + parent.fmt(v.host.txRate); color: v.fg; opacity: 0.7; font.family: v.font; font.pixelSize: 13; font.weight: Font.DemiBold }
    Item {
      id: graph
      x: 14; y: 60; width: v.tileW - 28; height: 92
      readonly property var rx: v.host.rxHistory || []
      readonly property var tx: v.host.txHistory || []
      readonly property real peak: Math.max(1024, Math.max.apply(null, rx.concat(tx).concat([1])))
      Rectangle { y: graph.height / 2; width: graph.width; height: 1; color: v.fg; opacity: 0.15 }
      Repeater {
        model: graph.rx.length
        Rectangle {
          required property int index
          readonly property real hh: (graph.height / 2 - 2) * Math.sqrt(graph.rx[index] / graph.peak)
          x: index * graph.width / Math.max(1, graph.rx.length); width: Math.max(1, graph.width / Math.max(1, graph.rx.length) - 1)
          y: graph.height / 2 - hh; height: hh; radius: 1
          color: v.acc; opacity: 0.85
        }
      }
      Repeater {
        model: graph.tx.length
        Rectangle {
          required property int index
          readonly property real hh: (graph.height / 2 - 2) * Math.sqrt(graph.tx[index] / graph.peak)
          x: index * graph.width / Math.max(1, graph.tx.length); width: Math.max(1, graph.width / Math.max(1, graph.tx.length) - 1)
          y: graph.height / 2 + 1; height: hh; radius: 1
          color: v.fg; opacity: 0.45
        }
      }
    }
  }
  // 7. хост: имя, аптайм, батарея
  Tile {
    i: 6; col: 3; row: 1
    Cap { x: 16; y: 14; text: "HOST" }
    Text { x: 16; y: 32; width: v.tileW - 32; elide: Text.ElideRight; text: v.host.hostName || "—"; color: v.fg; font.family: v.font; font.pixelSize: 18; font.weight: Font.Bold }
    Text {
      x: 16; y: 60
      readonly property int up: Math.floor(v.host.uptime || 0)
      text: "up " + (up >= 86400 ? Math.floor(up / 86400) + "d " : "") + Math.floor(up % 86400 / 3600) + "h " + Math.floor(up % 3600 / 60) + "m"
      color: v.fg; opacity: 0.65; font.family: v.font; font.pixelSize: 13
    }
    // батарея — горизонтальная «ёмкость» с уровнем
    Item {
      visible: v.host.battery >= 0
      x: 16; y: 100; width: v.tileW - 40; height: 40
      Rectangle { width: parent.width - 6; height: 28; radius: 8; color: "transparent"; border.width: 2; border.color: Qt.rgba(v.fg.r, v.fg.g, v.fg.b, 0.5)
        Rectangle { x: 4; y: 4; height: parent.height - 8; radius: 4
          width: (parent.width - 8) * Math.max(0, Math.min(1, v.host.battery / 100))
          color: v.host.battery <= 15 ? "#ff6b5e" : v.acc } }
      Rectangle { x: parent.width - 5; y: 9; width: 5; height: 10; radius: 2; color: Qt.rgba(v.fg.r, v.fg.g, v.fg.b, 0.5) }
      Text { anchors.centerIn: parent; anchors.horizontalCenterOffset: -3; text: v.host.battery + "%" + (String(v.host.batteryStatus).toLowerCase() === "charging" ? " ⚡" : "")
        color: v.fg; font.family: v.font; font.pixelSize: 13; font.weight: Font.Bold; style: Text.Outline; styleColor: v.host.background }
    }
  }
}

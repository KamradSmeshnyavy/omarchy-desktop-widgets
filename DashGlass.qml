import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Дашборд Vitreus (dashStyle "vitreus", по мотивам natepayn3/Vitreus, MIT; код свой) — «всё сразу, всплывает сквозь
// стекло». Стеклянные плитки: две высокие колбы-ползунки (громкость, яркость), часы с градиентом и шкалой дня +
// напоминания (omarchy-reminder), уведомления (история плагина уведомлений), батарея с кнопкой питания, карточка
// пользователя (аватар ~/.face, хост, дистрибутив, ядро, аптайм), кольца CPU / памяти / GPU и сеть, погода с деталями и
// прогнозом на 7 дней, плеер с обложкой в кольце визуализатора и волной прогресса. Плитки всплывают по очереди (rise).
Item {
  id: g

  required property var host
  property real rise: 1
  readonly property color fg: host.foreground
  readonly property color bg: host.background
  readonly property color acc: host.accent
  // на светлой теме «яркий» акцент — темнее (иначе бледные надписи не читаются)
  readonly property bool light: (0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b) > 0.55
  readonly property color accHi: light ? Qt.darker(acc, 1.3) : Qt.lighter(acc, 1.45)
  readonly property color accFar: light ? Qt.darker(acc, 1.7) : Qt.lighter(acc, 1.75)
  readonly property string font: "Space Grotesk"
  readonly property string icons: host.iconFamily

  implicitWidth: 1205
  implicitHeight: 540

  function pct(x) { return Math.round(Math.max(0, Math.min(1, x)) * 100) }
  function kbs(b) { return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB/s" : b >= 1024 ? Math.round(b / 1024) + " KB/s" : Math.round(b) + " B/s" }

  // ── данные ─────────────────────────────────────────────────────────
  PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
  readonly property var sink: Pipewire.defaultAudioSink
  property real bright: -1             // -1 — подсветки нет
  property var reminders: []
  property var notes: []
  property string userName: Quickshell.env("USER") || "user"
  property string distro: ""
  property string kernel: ""
  property string netName: ""
  // аватар: dashAvatar из widgets.json (Customizer → Дашборд), иначе ~/.face
  readonly property string avatar: {
    var a = String(host.value("dashAvatar") || "")
    if (!a) a = "~/.face"
    if (a.indexOf("~") === 0) a = Quickshell.env("HOME") + a.slice(1)
    return a.replace(/^file:\/\//, "")
  }
  property bool hasFace: false        // файл аватара есть (иначе — буква имени, без попытки грузить)
  onAvatarChanged: if (!sysRead.running) sysRead.running = true
  readonly property bool live: rise > 0.99

  Process {
    id: brRead
    command: ["bash", "-c", "brightnessctl -m 2>/dev/null | head -1"]
    stdout: StdioCollector { onStreamFinished: { var f = text.split(","); g.bright = f.length > 3 ? Math.max(0, Math.min(1, parseFloat(f[3]) / 100)) : -1 } }
  }
  Process {
    id: remRead
    command: ["omarchy-reminder", "show", "--json"]
    stdout: StdioCollector { onStreamFinished: { try { g.reminders = JSON.parse(text).reminders || [] } catch (e) { g.reminders = [] } } }
  }
  Process {
    id: notesRead
    command: ["bash", "-c", "cd \"$HOME/.local/state/omarchy/notifications/history\" 2>/dev/null && for f in $(ls -t | head -6); do cat \"$f\"; echo; done"]
    stdout: StdioCollector {
      onStreamFinished: {
        var out = []
        text.split("\n").forEach(function(l) { if (l.trim()) try { out.push(JSON.parse(l)) } catch (e) {} })
        g.notes = out
      }
    }
  }
  Process {
    id: sysRead
    command: ["bash", "-c", ". /etc/os-release 2>/dev/null; echo \"$NAME\"; uname -r; test -f \"$1\" && echo face || echo -;" +
      "nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep -v ':loopback' | head -1 | cut -d: -f1", "sys", g.avatar]
    stdout: StdioCollector {
      onStreamFinished: {
        var l = text.split("\n")
        g.distro = l[0] || ""; g.kernel = l[1] || ""; g.hasFace = l[2] === "face"; g.netName = l[3] || ""
      }
    }
  }
  function refresh() {
    if (!brRead.running) brRead.running = true
    if (!remRead.running) remRead.running = true
    if (!notesRead.running) notesRead.running = true
    if (!sysRead.running) sysRead.running = true
  }
  onLiveChanged: if (live) refresh()
  Timer { interval: 15000; repeat: true; running: g.live; onTriggered: g.refresh() }
  function setBright(x) { g.bright = x; Quickshell.execDetached(["brightnessctl", "-q", "set", Math.round(x * 100) + "%"]) }

  // ── общие части ────────────────────────────────────────────────────
  // плитка всплывает со своей задержкой: снизу вверх с лёгким перелётом
  component Tile: Rectangle {
    id: tile
    property int i: 0
    readonly property real kk: Math.max(0, Math.min(1, g.rise * 1.8 - i * 0.1))
    readonly property real ease: kk >= 1 ? 1 : 1 - Math.pow(1 - kk, 3) * (1 - 1.7 * kk * (1 - kk))
    transform: Translate { y: (1 - tile.ease) * 40 }
    opacity: Math.min(1, kk * 1.6)
    radius: 20
    color: Qt.rgba(g.bg.r, g.bg.g, g.bg.b, 0.32)
    border.width: 1
    border.color: Qt.rgba(g.fg.r, g.fg.g, g.fg.b, 0.16)
    // блик по верхней кромке
    Rectangle {
      x: 1; y: 1; width: parent.width - 2; height: Math.min(40, parent.height / 3); radius: parent.radius
      gradient: Gradient { GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.07) } GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) } }
    }
  }
  component Lbl: Text {
    color: g.fg
    font.family: g.font
    font.pixelSize: 12
    font.weight: Font.Medium
  }
  component Ico: Text {
    color: g.acc
    font.family: g.icons
    font.pixelSize: 14
  }
  // текст градиентом (светлый → акцент)
  component GradText: Item {
    id: gt
    property string text
    property real px: 40
    property color c0: g.accHi
    property color c1: g.acc
    implicitWidth: tt.implicitWidth; implicitHeight: tt.implicitHeight
    Text { id: tt; text: gt.text; font.family: g.font; font.pixelSize: Math.round(gt.px); font.weight: Font.DemiBold; color: "white"; visible: false; layer.enabled: true }
    Rectangle {
      id: gr; anchors.fill: tt; visible: false; layer.enabled: true
      gradient: Gradient { GradientStop { position: 0.15; color: gt.c0 } GradientStop { position: 1; color: gt.c1 } }
    }
    MultiEffect { anchors.fill: tt; source: gr; maskEnabled: true; maskSource: tt; maskThresholdMin: 0.4; maskSpreadAtMin: 0.3 }
  }
  // кольцо-показатель
  component Ring: Item {
    id: rg
    property real value: 0
    property string label
    width: 74; height: 96
    Shape {
      width: 70; height: 70; x: 2
      preferredRendererType: Shape.CurveRenderer
      ShapePath { strokeColor: Qt.rgba(g.fg.r, g.fg.g, g.fg.b, 0.12); strokeWidth: 5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: 35; centerY: 35; radiusX: 30; radiusY: 30; startAngle: 135; sweepAngle: 270 } }
      ShapePath { strokeColor: g.acc; strokeWidth: 5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: 35; centerY: 35; radiusX: 30; radiusY: 30; startAngle: 135; sweepAngle: 270 * Math.max(0.01, Math.min(1, rg.value)) } }
    }
    Lbl { x: 2; width: 70; y: 26; horizontalAlignment: Text.AlignHCenter; text: g.pct(rg.value) + "%"; font.pixelSize: 14; font.weight: Font.Bold; color: g.accHi }
    Lbl { width: rg.width; y: 76; horizontalAlignment: Text.AlignHCenter; text: rg.label; opacity: 0.65; font.pixelSize: 11 }
  }
  // высокая колба-ползунок
  component Flask: Tile {
    id: fl
    property real value: 0
    property string caption
    property string icon
    property bool enabledSlider: true
    signal moved(real v)
    radius: 30
    readonly property real inner: height - 50 - 10      // от ручки при 100 % до низа колбы
    Lbl { anchors.horizontalCenter: parent.horizontalCenter; y: 16; text: fl.caption; font.pixelSize: fl.enabledSlider ? 15 : 10; font.weight: Font.DemiBold; opacity: fl.enabledSlider ? 1 : 0.6 }
    // заливка снизу
    Item {
      visible: fl.enabledSlider
      x: 10; width: parent.width - 20
      // низ колбы залит всегда (на нём значок), выше — по уровню
      readonly property real h: 44 + (fl.inner - 44) * fl.value
      y: 50 + fl.inner - h; height: h
      Rectangle {
        anchors.fill: parent; anchors.topMargin: 6; radius: 18
        gradient: Gradient { GradientStop { position: 0; color: g.acc } GradientStop { position: 1; color: Qt.darker(g.acc, 1.25) } }
        Rectangle { x: 6; y: 8; width: 3; height: Math.max(0, parent.height - 26); radius: 1.5; color: Qt.rgba(1, 1, 1, 0.3) }
      }
      // ручка — светлая плашка шире колбы
      Rectangle { x: -6; y: -4; width: parent.width + 12; height: 12; radius: 6; color: g.accHi
        layer.enabled: true; layer.effect: MultiEffect { shadowEnabled: true; shadowColor: g.acc; shadowBlur: 0.6; shadowOpacity: 0.6 } }
    }
    Ico { anchors.horizontalCenter: parent.horizontalCenter; y: parent.height - 34; text: fl.icon; font.pixelSize: 17
      color: fl.enabledSlider ? g.bg : g.fg; opacity: fl.enabledSlider ? 1 : 0.6 }
    MouseArea {
      enabled: fl.enabledSlider
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      function at(my) { return Math.max(0, Math.min(1, (50 + fl.inner - 44 - my) / (fl.inner - 44) + 0)) }
      onPressed: function(m) { fl.moved(at(m.y)) }
      onPositionChanged: function(m) { if (pressed) fl.moved(at(m.y)) }
      onWheel: function(w) { fl.moved(Math.max(0, Math.min(1, fl.value + (w.angleDelta.y > 0 ? 0.05 : -0.05)))) }
    }
  }

  // ── колбы ──────────────────────────────────────────────────────────
  Flask {
    i: 0; x: 0; y: 0; width: 74; height: 540
    value: g.sink && g.sink.audio ? Math.min(1, g.sink.audio.volume) : 0
    caption: g.pct(value) + "%"
    icon: g.sink && g.sink.audio && g.sink.audio.muted ? "󰝟" : "󰕾"
    onMoved: function(x) { if (g.sink && g.sink.audio) g.sink.audio.volume = x }
  }
  Flask {
    i: 1; x: 90; y: 0; width: 74; height: 540
    enabledSlider: g.bright >= 0
    value: Math.max(0, g.bright)
    caption: g.bright >= 0 ? g.pct(g.bright) + "%" : g.host.tr("No backlight", "Нет подсветки")
    icon: "󰃟"
    onMoved: function(x) { g.setBright(x) }
  }

  // ── часы и напоминания ─────────────────────────────────────────────
  Tile {
    i: 2; x: 180; y: 0; width: 607; height: 180
    SystemClock { id: clk; precision: SystemClock.Minutes }
    Row {
      x: 22; y: 18; spacing: 8
      GradText { text: Qt.formatTime(clk.date, "HH"); px: 92; c0: g.accFar; c1: g.acc }
      Rectangle { width: 3; height: 66; y: 26; radius: 1.5; color: g.acc }
      GradText { y: 30; text: Qt.formatTime(clk.date, "mm"); px: 62; c0: g.acc; c1: g.accFar }
    }
    Lbl { x: 26; y: 132; text: Qt.locale().toString(clk.date, "ddd d MMM"); font.pixelSize: 15; opacity: 0.85 }
    // шкала дня: риски каждые полчаса, метка — сейчас
    Item {
      x: 22; y: 160; width: 210; height: 10
      Repeater {
        model: 49
        Rectangle { required property int index; x: index * parent.width / 48; width: 1; height: index % 6 === 0 ? 7 : 4; y: 10 - height
          color: g.fg; opacity: 0.3 }
      }
      Rectangle { x: (clk.date.getHours() * 60 + clk.date.getMinutes()) / 1440 * parent.width - 1; width: 3; height: 10; radius: 1.5; color: g.acc }
    }
    Rectangle { x: 238; y: 18; width: 1; height: 144; color: g.fg; opacity: 0.14 }
    Lbl { x: 256; y: 22; text: g.host.tr("Reminders", "Напоминания"); font.pixelSize: 13; font.weight: Font.DemiBold }
    Lbl { anchors.right: parent.right; anchors.rightMargin: 22; y: 22; text: g.host.tr("Today", "Сегодня"); opacity: 0.6; font.pixelSize: 11 }
    Lbl {
      visible: g.reminders.length === 0
      x: 256; width: parent.width - 256 - 22; y: 84
      horizontalAlignment: Text.AlignHCenter
      text: g.host.tr("Nothing for today", "На сегодня ничего"); opacity: 0.7
    }
    Column {
      x: 256; y: 48; width: parent.width - 256 - 22; spacing: 6
      Repeater {
        model: g.reminders.slice(0, 4)
        Rectangle {
          required property var modelData
          width: parent.width; height: 24; radius: 8
          color: Qt.rgba(g.fg.r, g.fg.g, g.fg.b, 0.06)
          Ico { x: 8; anchors.verticalCenter: parent.verticalCenter; text: "󰀠"; font.pixelSize: 12 }
          Lbl { x: 28; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 100; elide: Text.ElideRight; text: modelData.label || "" }
          Lbl { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; text: modelData.atTime || ""; color: g.acc; font.weight: Font.DemiBold }
        }
      }
    }
  }

  // ── уведомления ────────────────────────────────────────────────────
  Tile {
    i: 3; x: 180; y: 196; width: 268; height: 247
    Lbl { x: 18; y: 20; text: g.host.tr("Notifications", "Уведомления"); font.pixelSize: 13; font.weight: Font.DemiBold }
    Rectangle {
      x: parent.width - 108; y: 14; width: 50; height: 26; radius: 13
      color: Qt.rgba(g.fg.r, g.fg.g, g.fg.b, clearArea.containsMouse ? 0.14 : 0.08)
      Lbl { anchors.centerIn: parent; text: g.host.tr("Clear", "Очист."); font.pixelSize: 11; font.weight: Font.DemiBold }
      MouseArea { id: clearArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: { Quickshell.execDetached(["omarchy-shell", "notifications", "clear"]); g.notes = [] } }
    }
    Rectangle {
      x: parent.width - 48; y: 14; width: 30; height: 26; radius: 13
      color: Qt.rgba(g.fg.r, g.fg.g, g.fg.b, dndArea.containsMouse ? 0.14 : 0.08)
      Ico { anchors.centerIn: parent; text: "󰂚"; color: g.fg; font.pixelSize: 13 }
      MouseArea { id: dndArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["omarchy-shell", "notifications", "toggleDnd"]) }
    }
    Lbl { visible: g.notes.length === 0; anchors.centerIn: parent; text: g.host.tr("All clear", "Пусто"); opacity: 0.6 }
    Column {
      x: 12; y: 52; width: parent.width - 24; spacing: 6
      Repeater {
        model: g.notes.slice(0, 4)
        Rectangle {
          required property var modelData
          width: parent.width; height: 44; radius: 10
          color: Qt.rgba(g.fg.r, g.fg.g, g.fg.b, 0.05)
          Rectangle { x: 8; y: 12; width: 6; height: 6; radius: 3; color: g.acc }
          Lbl { x: 20; y: 6; width: parent.width - 90; elide: Text.ElideRight; text: modelData.app || modelData.summary || ""; color: g.accHi; font.pixelSize: 12; font.weight: Font.DemiBold }
          Lbl { anchors.right: parent.right; anchors.rightMargin: 8; y: 7; text: modelData.timestamp ? Qt.formatTime(new Date(modelData.timestamp), "HH:mm") : ""; opacity: 0.55; font.pixelSize: 10 }
          Lbl { x: 20; y: 24; width: parent.width - 28; elide: Text.ElideRight; opacity: 0.7; font.pixelSize: 11
            text: (modelData.summary && modelData.app ? modelData.summary + (modelData.body ? " · " : "") : "") + (modelData.body || "") }
        }
      }
    }
  }

  // ── батарея ────────────────────────────────────────────────────────
  Tile {
    i: 4; x: 180; y: 459; width: 268; height: 81
    readonly property int b: g.host.battery
    Rectangle {
      x: 18; y: 22; width: 100; height: 36; radius: 12
      color: "transparent"; border.width: 1.5; border.color: Qt.rgba(g.fg.r, g.fg.g, g.fg.b, 0.35)
      Rectangle { x: 3; y: 3; height: parent.height - 6; radius: 9
        width: (parent.width - 6) * Math.max(0.04, Math.min(1, parent.parent.b / 100))
        color: parent.parent.b <= 15 ? "#ff6b5e" : Qt.rgba(g.acc.r, g.acc.g, g.acc.b, 0.75) }
      Lbl { anchors.centerIn: parent; text: parent.parent.b >= 0 ? parent.parent.b + "%" : "AC"; font.pixelSize: 14; font.weight: Font.Bold; color: g.accHi }
    }
    Rectangle { x: 120; y: 33; width: 3; height: 14; radius: 1.5; color: Qt.rgba(g.fg.r, g.fg.g, g.fg.b, 0.35) }
    Lbl { x: 132; anchors.verticalCenter: parent.verticalCenter; opacity: 0.7; font.pixelSize: 11
      text: String(g.host.batteryStatus).toLowerCase() === "charging" ? g.host.tr("Charging", "Заряжается")
        : parent.b >= 0 ? g.host.tr("On battery", "От батареи") : g.host.tr("On power", "От сети") }
    Rectangle {
      anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
      width: 38; height: 38; radius: 19
      color: pwrArea.containsMouse ? g.accHi : g.acc
      Ico { anchors.centerIn: parent; text: "󰐥"; color: g.bg; font.pixelSize: 17 }
      MouseArea { id: pwrArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: { g.host.dashboardOpen = false; g.host.powerOpen = true } }
    }
  }

  // ── пользователь ───────────────────────────────────────────────────
  Tile {
    i: 5; x: 464; y: 196; width: 323; height: 130
    Rectangle {
      x: 14; y: 13; width: 104; height: 104; radius: 52
      color: Qt.rgba(g.fg.r, g.fg.g, g.fg.b, 0.08)
      border.width: 4; border.color: g.acc
      Image {
        id: face
        visible: status === Image.Ready
        anchors.fill: parent; anchors.margins: 7
        source: g.hasFace ? "file://" + g.avatar : ""
        sourceSize: Qt.size(200, 200)
        cache: false
        fillMode: Image.PreserveAspectCrop
        layer.enabled: true
        layer.effect: MultiEffect { maskEnabled: true; maskSource: faceMask; maskThresholdMin: 0.5 }
      }
      Rectangle { id: faceMask; anchors.fill: face; radius: width / 2; visible: false; layer.enabled: true }
      Lbl { visible: face.status !== Image.Ready; anchors.centerIn: parent; text: g.userName.charAt(0).toUpperCase(); font.pixelSize: 40; font.weight: Font.Bold; color: g.acc }
    }
    Lbl { x: 134; y: 14; width: parent.width - 134 - 90; elide: Text.ElideRight; text: g.userName; font.pixelSize: 20; font.weight: Font.DemiBold }
    Row {
      anchors.right: parent.right; anchors.rightMargin: 16; y: 20; spacing: 4
      Ico { text: "󱎫"; font.pixelSize: 12 }
      Lbl {
        readonly property int up: Math.floor(g.host.uptime || 0)
        text: (up >= 86400 ? Math.floor(up / 86400) + "d " : "") + Math.floor(up % 86400 / 3600) + "h " + Math.floor(up % 3600 / 60) + "m"
        color: g.acc; font.pixelSize: 11; font.weight: Font.DemiBold
      }
    }
    Column {
      x: 130; y: 46; width: parent.width - 146; spacing: 4
      Repeater {
        model: [["󰌢", g.host.hostName], ["󰣇", g.distro], ["󰌽", g.kernel]]
        Rectangle {
          required property var modelData
          width: parent.width; height: 22; radius: 7
          color: Qt.rgba(g.fg.r, g.fg.g, g.fg.b, 0.05)
          Ico { x: 8; anchors.verticalCenter: parent.verticalCenter; text: modelData[0]; font.pixelSize: 12 }
          Lbl { x: 28; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 34; elide: Text.ElideRight; text: modelData[1] || "—"; font.pixelSize: 12 }
        }
      }
    }
  }

  // ── система и сеть ─────────────────────────────────────────────────
  Tile {
    i: 6; x: 464; y: 342; width: 323; height: 198
    Row {
      x: 22; y: 16; spacing: 26
      Ring { value: g.host.cpu; label: "CPU" }
      Ring { value: g.host.mem; label: g.host.tr("Memory", "Память") }
      // нет загрузки видеокарты — температура (из 100 °C)
      Ring { value: g.host.gpu >= 0 ? g.host.gpu / 100 : (g.host.temp || 0) / 100; label: g.host.gpu >= 0 ? "GPU" : g.host.tr("Temp", "Темп.") }
    }
    Ico { x: 22; y: 132; text: g.netName ? "󰈀" : "󰤮"; font.pixelSize: 13 }
    Lbl { x: 44; y: 132; width: parent.width - 66; elide: Text.ElideRight; text: g.netName || g.host.tr("Offline", "Нет сети"); color: g.accHi; font.weight: Font.DemiBold }
    Ico { x: 22; y: 160; text: "󰇚"; font.pixelSize: 12; opacity: 0.8 }
    Lbl { x: 40; y: 160; text: g.kbs(g.host.rxRate); opacity: 0.75; font.pixelSize: 11 }
    Ico { x: 170; y: 160; text: "󰕒"; font.pixelSize: 12; opacity: 0.8 }
    Lbl { x: 188; y: 160; text: g.kbs(g.host.txRate); opacity: 0.75; font.pixelSize: 11 }
  }

  // ── погода ─────────────────────────────────────────────────────────
  Tile {
    id: wxTile
    i: 7; x: 803; y: 0; width: 402; height: 250
    readonly property var w: g.host.weather
    readonly property bool ok: !!w && w.error === undefined && w.temp !== undefined
    readonly property string unit: String(g.host.value("weatherUnits")) === "fahrenheit" ? "°F" : "°C"
    function wx(code) {
      var t = [[[0], "󰖙", "Clear sky", "Ясно"], [[1, 2], "󰖕", "Partly cloudy", "Облачно"], [[3], "󰖐", "Overcast", "Пасмурно"],
               [[45, 48], "󰖑", "Fog", "Туман"], [[51, 53, 55, 56, 57], "󰖗", "Drizzle", "Морось"],
               [[61, 63, 65, 66, 67, 80, 81, 82], "󰖖", "Rain", "Дождь"], [[71, 73, 75, 77, 85, 86], "󰖘", "Snow", "Снег"], [[95, 96, 99], "󰖓", "Storm", "Гроза"]]
      for (var i = 0; i < t.length; i++) if (t[i][0].indexOf(code) !== -1) return { glyph: t[i][1], text: g.host.tr(t[i][2], t[i][3]) }
      return { glyph: "󰖐", text: "" }
    }
    function dir(deg) { return ["N", "NE", "E", "SE", "S", "SW", "W", "NW"][Math.round(((deg || 0) % 360) / 45) % 8] }
    Lbl { visible: !wxTile.ok; anchors.centerIn: parent; width: parent.width - 40; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; opacity: 0.65
      text: wxTile.w && wxTile.w.error ? wxTile.w.error : g.host.tr("Set a city: Customizer → Widgets → Dashboard", "Задай город: Customizer → Виджеты → Дашборд") }
    Item {
      visible: wxTile.ok
      anchors.fill: parent
      Ico { x: 22; y: 18; text: wxTile.ok ? wxTile.wx(wxTile.w.code).glyph : ""; font.pixelSize: 38 }
      Lbl { x: 18; y: 70; width: 90; elide: Text.ElideRight; text: wxTile.ok ? wxTile.wx(wxTile.w.code).text : ""; opacity: 0.75 }
      Grid {
        x: 110; y: 20; columns: 2; columnSpacing: 18; rowSpacing: 8
        Repeater {
          model: wxTile.ok ? [
            ["󰔏", Math.round(wxTile.w.feels) + "°", g.host.tr("Feels like", "Ощущается")],
            ["󰖎", (wxTile.w.humidity !== undefined ? Math.round(wxTile.w.humidity) : "—") + "%", g.host.tr("Humidity", "Влажность")],
            ["󰖝", Math.round(wxTile.w.wind) + " " + wxTile.dir(wxTile.w.windDir), g.host.tr("Wind", "Ветер")],
            ["󰖗", (wxTile.w.rain !== null && wxTile.w.rain !== undefined ? Math.round(wxTile.w.rain) : "—") + "%", g.host.tr("Rain today", "Дождь")]
          ] : []
          Row {
            required property var modelData
            spacing: 6
            Ico { text: modelData[0]; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
            Column {
              Lbl { text: modelData[1]; color: g.accHi; font.pixelSize: 12; font.weight: Font.DemiBold }
              Lbl { text: modelData[2]; opacity: 0.55; font.pixelSize: 9 }
            }
          }
        }
      }
      GradText { anchors.right: parent.right; anchors.rightMargin: 20; y: 26; text: wxTile.ok ? Math.round(wxTile.w.temp) + wxTile.unit : ""; px: 40; c0: g.fg; c1: g.accHi }
      Rectangle { x: 18; y: 118; width: parent.width - 36; height: 1; color: g.fg; opacity: 0.1 }
      Row {
        x: 14; y: 130; width: parent.width - 28
        Repeater {
          model: wxTile.ok && wxTile.w.days ? wxTile.w.days.slice(0, 7) : []
          Column {
            required property var modelData
            required property int index
            width: (wxTile.width - 28) / 7
            spacing: 6
            Lbl { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.locale().toString(new Date(modelData.date + "T12:00:00"), "ddd"); font.pixelSize: 11; color: index === 0 ? g.acc : g.fg; opacity: index === 0 ? 1 : 0.7 }
            Ico { anchors.horizontalCenter: parent.horizontalCenter; text: wxTile.wx(modelData.code).glyph; font.pixelSize: 17; color: index === 0 ? g.acc : g.fg; opacity: 0.85 }
            Lbl { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(modelData.max) + "°"; color: g.accHi; font.pixelSize: 12; font.weight: Font.DemiBold }
            Lbl { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(modelData.min) + "°"; opacity: 0.5; font.pixelSize: 11 }
          }
        }
      }
    }
  }

  // ── плеер ──────────────────────────────────────────────────────────
  Tile {
    id: pl
    i: 8; x: 803; y: 266; width: 402; height: 274
    readonly property var p: g.host.player
    readonly property bool has: !!p
    readonly property real prog: has && p.lengthSupported && p.length > 0 ? Math.max(0, Math.min(1, p.position / p.length)) : 0
    function clock(sec) { sec = Math.max(0, Math.floor(sec || 0)); var m = Math.floor(sec / 60), s = sec % 60; return m + ":" + (s < 10 ? "0" : "") + s }
    Timer { interval: 1000; repeat: true; running: pl.has && g.live && pl.p.isPlaying; onTriggered: if (pl.p.positionChanged) pl.p.positionChanged() }
    // обложка в кольце визуализатора
    Item {
      x: 18; y: 22; width: 184; height: 184
      Repeater {
        model: 56
        Rectangle {
          required property int index
          readonly property var lv: g.host.levels || []
          readonly property real v: lv.length ? (lv[Math.floor(index / 56 * lv.length)] || 0) : 0.15
          readonly property real len: 6 + 18 * Math.min(1, v)
          x: 92 - 1.5; y: 92 - 64 - len
          width: 3; height: len; radius: 1.5
          color: g.acc; opacity: 0.85
          transform: Rotation { origin.x: 1.5; origin.y: 64 + len; angle: index * 360 / 56 }
        }
      }
      Rectangle {
        x: 92 - 62; y: 92 - 62; width: 124; height: 124; radius: 62
        color: Qt.rgba(g.fg.r, g.fg.g, g.fg.b, 0.08)
        border.width: 2; border.color: Qt.rgba(g.fg.r, g.fg.g, g.fg.b, 0.2)
        Image {
          id: art
          anchors.fill: parent; anchors.margins: 3
          source: pl.has ? (pl.p.trackArtUrl || "") : ""
          fillMode: Image.PreserveAspectCrop
          visible: status === Image.Ready
          layer.enabled: true
          layer.effect: MultiEffect { maskEnabled: true; maskSource: artMask; maskThresholdMin: 0.5 }
        }
        Rectangle { id: artMask; anchors.fill: art; radius: width / 2; visible: false; layer.enabled: true }
        Ico { visible: art.status !== Image.Ready; anchors.centerIn: parent; text: "󰝚"; font.pixelSize: 40 }
      }
    }
    Lbl { x: 222; y: 26; text: g.host.tr("Now playing", "Сейчас играет"); opacity: 0.6; font.pixelSize: 11 }
    Lbl { x: 222; y: 50; width: parent.width - 240; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
      text: pl.has ? (pl.p.trackTitle || "—") : g.host.tr("Nothing playing", "Ничего не играет"); font.pixelSize: 16; font.weight: Font.DemiBold }
    Lbl { x: 222; y: 96; width: parent.width - 240; elide: Text.ElideRight; text: pl.has ? (pl.p.trackArtist || "") : ""; opacity: 0.65; font.pixelSize: 12 }
    Row {
      x: 240; y: 150; spacing: 22
      Ico { anchors.verticalCenter: parent.verticalCenter; text: "󰒮"; color: g.fg; font.pixelSize: 18
        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: if (pl.has) pl.p.previous() } }
      Rectangle {
        width: 46; height: 46; radius: 23; color: playArea.containsMouse ? g.accHi : g.acc
        Ico { anchors.centerIn: parent; text: pl.has && pl.p.isPlaying ? "󰏤" : "󰐊"; color: g.bg; font.pixelSize: 20 }
        MouseArea { id: playArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (pl.has) pl.p.togglePlaying() }
      }
      Ico { anchors.verticalCenter: parent.verticalCenter; text: "󰒭"; color: g.fg; font.pixelSize: 18
        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: if (pl.has) pl.p.next() } }
    }
    // волна прогресса: пройденное — волной, остаток — прямой
    Lbl { x: 18; y: 232; text: pl.has ? pl.clock(pl.p.position) : "0:00"; opacity: 0.7; font.pixelSize: 11 }
    property real phase: 0
    NumberAnimation on phase { from: 0; to: 1; duration: 1600; loops: Animation.Infinite; running: pl.has && g.live && pl.p.isPlaying }
    Shape {
      x: 64; y: 228; width: pl.width - 140; height: 20
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: g.acc; strokeWidth: 2.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
        PathPolyline {
          path: {
            var pts = [], W = pl.width - 140, n = 60, end = W * Math.max(0.02, pl.prog)
            for (var i = 0; i <= n; i++) { var x = end * i / n; pts.push(Qt.point(x, 10 + 4 * Math.sin(2 * Math.PI * (x / 18 - pl.phase)))) }
            return pts
          }
        }
      }
      ShapePath {
        strokeColor: Qt.rgba(g.fg.r, g.fg.g, g.fg.b, 0.2); strokeWidth: 2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
        PathMove { x: (pl.width - 140) * Math.max(0.02, pl.prog) + 4; y: 10 }
        PathLine { x: pl.width - 140; y: 10 }
      }
    }
    Lbl { anchors.right: parent.right; anchors.rightMargin: 18; y: 232; color: g.acc; font.weight: Font.DemiBold; font.pixelSize: 11
      text: pl.has && pl.p.lengthSupported && pl.p.length > 0 ? pl.clock(pl.p.length) : "Live" }
  }
}

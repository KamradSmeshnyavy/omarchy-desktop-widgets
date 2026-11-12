import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "dotmatrix" as DotMatrix

// Домашний экран (по мотивам glyph-rice): на слое Bottom, только пока на активном столе этого
// монитора нет окон. Точечная сетка, крупные часы, приветствие по времени суток, дата и сетка 3×3
// плиток (плеер, погода, CPU, RAM, батарея, температура, сеть, прогресс дня, день года).
// Ключи widgets.json: home (выкл. по умолчанию), homeName (имя в приветствии; пусто — $USER),
// homeDots (точечная сетка), homeHideWidgets (прятать виджеты на якорях, пока виден дом).
PanelWindow {
  id: home

  required property var host            // Widgets.qml
  required property var modelData       // экран

  readonly property var monitor: Hyprland.monitorFor(modelData)
  readonly property int wsId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
  // Окна на активном столе этого монитора (спецстолы вроде scratchpad не в счёт).
  readonly property int windowCount: {
    var list = Hyprland.toplevels.values, n = 0
    for (var i = 0; i < list.length; i++) if (list[i].workspace && list[i].workspace.id === wsId) n++
    return n
  }
  readonly property bool shown: wsId > 0 && windowCount === 0
  onShownChanged: host.setHomeShown(String(modelData.name), shown)

  screen: modelData
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Normal
  color: "transparent"
  surfaceFormat.opaque: false
  visible: shown || fade.opacity > 0.01
  WlrLayershell.namespace: "omarchy-home"
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region { item: home.shown ? grid : null }

  // Окно открыли / закрыли / перенесли — toplevels обновляются по событиям, но workspace у
  // окна приходит чуть позже: короткий пересчёт после событий окон.
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (/^(openwindow|closewindow|movewindow|movewindowv2|workspace|workspacev2|focusedmon)$/.test(event.name)) refresh.restart()
    }
  }
  Timer { id: refresh; interval: 150; onTriggered: Hyprland.refreshToplevels() }

  readonly property bool dot: host.dotmatrixWidgets
  readonly property color fg: dot ? DotMatrix.Palette.fg : host.foreground
  readonly property color dim: dot ? DotMatrix.Palette.dim : Qt.rgba(host.foreground.r, host.foreground.g, host.foreground.b, 0.62)

  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: home.visible; triggeredOnStart: true; onTriggered: home.now = new Date() }

  readonly property string userName: {
    var n = String(host.value("homeName") || "").trim()
    if (n !== "") return n
    var u = String(Quickshell.env("USER") || "")
    return u.length > 0 ? u.charAt(0).toUpperCase() + u.slice(1) : ""
  }
  readonly property string greeting: {
    var h = now.getHours()
    var g = h < 5 ? host.tr("Good night", "Доброй ночи") : h < 12 ? host.tr("Good morning", "Доброе утро")
      : h < 18 ? host.tr("Good afternoon", "Добрый день") : host.tr("Good evening", "Добрый вечер")
    return userName !== "" ? g + ", " + userName : g
  }

  function rate(b) {
    return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB/s" : b >= 1024 ? Math.round(b / 1024) + " KB/s" : Math.round(b) + " B/s"
  }

  Item {
    id: fade
    anchors.fill: parent
    opacity: home.shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: home.host.deskStyle.ms(320); easing.type: Easing.OutCubic } }

    // Точечная сетка: рисуется один раз на размер окна.
    Canvas {
      id: dots
      anchors.fill: parent
      visible: home.host.value("homeDots") !== false
      opacity: 0.16
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      property color c: home.fg
      onCChanged: requestPaint()
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.fillStyle = c
        var step = 22
        for (var y = step / 2; y < height; y += step)
          for (var x = step / 2; x < width; x += step) ctx.fillRect(Math.round(x), Math.round(y), 2, 2)
      }
    }

    Column {
      id: head
      anchors.horizontalCenter: parent.horizontalCenter
      y: Math.max(40, (parent.height - height - grid.height - 48) / 2)
      spacing: 6
      // Мягкая тень: текст читается и на светлых местах обоев.
      layer.enabled: true
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: 0.7
        shadowBlur: 0.9
        shadowVerticalOffset: 2
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatTime(home.now, home.host.value("clock24") !== false ? "HH:mm" : "h:mm")
        font.family: home.dot ? DotMatrix.Palette.fontDot : home.host.fontFamily
        font.pixelSize: 112
        font.weight: Font.Light
        color: home.fg
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: home.greeting
        font.family: home.dot ? DotMatrix.Palette.fontTitle : home.host.fontFamily
        font.pixelSize: 24
        color: home.fg
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: home.host.locale.toString(home.now, "dddd, d MMMM")
        font.family: home.dot ? DotMatrix.Palette.fontLabel : home.host.fontFamily
        font.pixelSize: 15
        font.capitalization: home.dot ? Font.AllUppercase : Font.MixedCase
        color: home.dim
      }
    }

    Grid {
      id: grid
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: head.bottom
      anchors.topMargin: 40
      columns: 3
      spacing: 14
      readonly property int cell: Math.min(220, Math.floor((home.width - 120) / 3))
      readonly property int cellH: 132

      readonly property var p: home.host.player
      HomeTile {
        host: home.host; seed: 41; width: grid.cell; height: grid.cellH
        icon: grid.p && grid.p.isPlaying ? "󰏤" : "󰐊"
        label: home.host.tr("Now playing", "Сейчас играет")
        value: grid.p && grid.p.trackTitle ? grid.p.trackTitle : home.host.tr("Silence", "Тишина")
        detail: grid.p ? (grid.p.trackArtist || grid.p.identity || "") : ""
        fill: grid.p && grid.p.lengthSupported && grid.p.length > 0 ? Math.min(1, grid.p.position / grid.p.length) : -1
        clickable: grid.p !== null
        onClicked: if (grid.p && grid.p.canTogglePlaying) grid.p.togglePlaying()
      }
      HomeTile {
        host: home.host; seed: 42; width: grid.cell; height: grid.cellH
        readonly property var w: home.host.weather
        icon: "󰖐"
        label: w && w.city ? w.city : home.host.tr("Weather", "Погода")
        value: w && w.temp !== undefined ? Math.round(w.temp) + "°" : "—"
        detail: w && w.error ? w.error : w && w.max !== undefined ? Math.round(w.min) + "° … " + Math.round(w.max) + "°"
          : home.host.tr("set weatherCity", "задай weatherCity")
        clickable: true
        onClicked: home.host.dashboardOpen = true
      }
      HomeTile {
        host: home.host; seed: 43; width: grid.cell; height: grid.cellH
        icon: "󰔟"
        label: home.host.tr("Day", "День")
        readonly property real dayPart: (home.now.getHours() * 3600 + home.now.getMinutes() * 60) / 86400
        value: Math.round(dayPart * 100) + "%"
        detail: home.host.tr("of the day has passed", "дня позади")
        fill: dayPart
      }
      HomeTile {
        host: home.host; seed: 44; width: grid.cell; height: grid.cellH
        icon: "󰻠"; label: "CPU"
        value: Math.round(home.host.cpu * 100) + "%"
        fill: home.host.cpu
        alert: home.host.cpu > 0.9
      }
      HomeTile {
        host: home.host; seed: 45; width: grid.cell; height: grid.cellH
        icon: "󰍛"; label: "RAM"
        value: Math.round(home.host.mem * 100) + "%"
        fill: home.host.mem
        alert: home.host.mem > 0.9
      }
      HomeTile {
        host: home.host; seed: 46; width: grid.cell; height: grid.cellH
        icon: home.host.batteryStatus === "Charging" ? "󰂄" : "󰁹"
        label: home.host.tr("Battery", "Батарея")
        value: home.host.battery >= 0 ? home.host.battery + "%" : "AC"
        detail: home.host.batteryStatus === "Charging" ? home.host.tr("charging", "заряжается")
          : home.host.batteryStatus === "Full" ? home.host.tr("full", "полная") : ""
        fill: home.host.battery >= 0 ? home.host.battery / 100 : -1
        alert: home.host.battery >= 0 && home.host.battery <= 15 && home.host.batteryStatus !== "Charging"
      }
      HomeTile {
        host: home.host; seed: 47; width: grid.cell; height: grid.cellH
        icon: "󰔏"
        label: home.host.tr("Temperature", "Температура")
        value: Math.round(home.host.temp) + "°"
        fill: Math.min(1, home.host.temp / 100)
        alert: home.host.temp >= 85
      }
      HomeTile {
        host: home.host; seed: 48; width: grid.cell; height: grid.cellH
        icon: "󰛳"
        label: home.host.netIface !== "" ? home.host.netIface : home.host.tr("Network", "Сеть")
        value: "↓ " + home.rate(home.host.rxRate)
        detail: "↑ " + home.rate(home.host.txRate)
      }
      HomeTile {
        host: home.host; seed: 49; width: grid.cell; height: grid.cellH
        readonly property int doy: Math.floor((home.now - new Date(home.now.getFullYear(), 0, 0)) / 86400000)
        readonly property int days: (new Date(home.now.getFullYear(), 1, 29).getDate() === 29) ? 366 : 365
        icon: "󰃭"
        label: home.host.tr("Year", "Год")
        value: doy + " / " + days
        detail: home.host.tr("week ", "неделя ") + Math.ceil(doy / 7)
        fill: doy / days
      }
    }
  }
}

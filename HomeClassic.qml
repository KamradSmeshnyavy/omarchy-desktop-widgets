import QtQuick
import QtQuick.Effects
import "dotmatrix" as DotMatrix

// Раскладка домашнего экрана «classic»: по центру часы, приветствие и дата, под ними плитки 3×3
// (HomeTile в материале стиля): плеер, погода, прогресс дня, CPU, RAM, батарея, температура, сеть, год.
Item {
  id: home

  required property var host          // Widgets.qml
  required property var homeScreen    // HomeScreen.qml
  readonly property date now: homeScreen.now
  readonly property string greeting: homeScreen.greeting
  readonly property bool dot: homeScreen.dot
  readonly property color fg: homeScreen.fg
  readonly property color dim: homeScreen.dim
  function rate(b) { return homeScreen.rate(b) }

  // Зона кликов для маски окна — плитки.
  readonly property Item hit: grid
  scale: Math.max(0.4, Math.min(2, Number(host.value("homeScale")) || 1))

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

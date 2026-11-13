import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "dotmatrix" as DotMatrix

// Deck — дашборд из-под нижнего края (по мотивам glyph-rice, код свой). Курсор задержался на полосе
// 2 px у нижнего края (deckDelay, 150 мс) — панель выезжает; ушёл с неё — через 300 мс прячется. Без
// затемнения и клавиатуры: подсмотреть и уйти. Окно на каждом экране, открыт не больше одного (host.deckOn).
// Закрыт — слой Top и только полоса; открыт — Overlay, виден и над полноэкранным окном; на столе с
// полноэкранным окном полоса не ловит курсор (игры, видео). IPC: widgets toggleDeck.
// Секции — deckSections по порядку: clock weather perf net media. Сцена — в пикселях макета 1920×1080,
// масштаб под экран (deckScale — множитель). Карточка — deckCards: glyph (плоская) или style (материал стиля).
// Раскладка — deckLayout: panel (секции колонками в одной карточке) · compact (тонкая полоска: время, кольца,
// трек, сеть) · full (на весь экран: затемнение, крупные часы и секции карточками; закрывается кликом по фону
// или Esc). Срабатывание — deckTrigger: dwell (задержаться у края deckDelay мс) · bump (толчок:
// коснуться края, чуть отвести курсор и снова в край за 0.6 с). «Давить» в край нельзя различить: у края
// Hyprland курсор держит и событий движения окну не шлёт.
PanelWindow {
  id: win

  required property var host            // Widgets.qml
  required property var modelData       // экран

  readonly property string name: String(modelData.name)
  readonly property bool open: host.deckOn === name
  readonly property var monitor: Hyprland.monitorFor(modelData)
  readonly property bool fullscreen: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.hasFullscreen === true : false
  property real t: open ? 1 : 0
  Behavior on t { NumberAnimation { duration: win.host.deskStyle.ms(320); easing.type: Easing.OutCubic } }

  readonly property real s: Math.min(modelData.width / 1920, modelData.height / 1080)
    * Math.max(0.5, Math.min(1.6, Number(host.value("deckScale")) || 1))
  readonly property var ids: String(host.value("deckSections") || "").split(/[\s,]+/)
    .filter(function(x) { return ["clock", "weather", "perf", "net", "media"].indexOf(x) !== -1 })
  readonly property int h: 232
  readonly property string layout: ["panel", "compact", "full"].indexOf(String(host.value("deckLayout"))) !== -1
    ? String(host.value("deckLayout")) : "panel"
  readonly property bool full: layout === "full"
  readonly property bool fullOpen: full && t > 0
  readonly property bool bump: String(host.value("deckTrigger")) === "bump"

  screen: modelData
  visible: (!fullscreen && ids.length > 0) || t > 0
  anchors.bottom: true
  // full: открыт — окно на весь экран; закрыт — только полоса по центру.
  anchors.top: fullOpen
  anchors.left: fullOpen
  anchors.right: fullOpen
  implicitWidth: full ? Math.ceil(640 * s) : Math.ceil(Math.max(200, panel.width) * s)
  implicitHeight: full ? 16 : Math.ceil((panel.height + 14) * s)
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  surfaceFormat.opaque: false
  WlrLayershell.layer: t > 0 ? WlrLayer.Overlay : WlrLayer.Top
  WlrLayershell.namespace: "omarchy-deck"
  WlrLayershell.keyboardFocus: fullOpen && open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  // Закрыт — мышь ловит только полоса у края, открыт — всё окно вместе со щелью под панелью.
  mask: Region { item: win.open ? hoverRoot : strip }

  Timer { id: dwell; interval: Math.max(0, win.host.num("deckDelay")); onTriggered: win.host.deckOn = win.name }
  Timer { id: leave; interval: 300; onTriggered: if (win.open) win.host.deckOn = "" }

  // ── Цвета, шрифты ──
  readonly property color fg: host.foreground
  readonly property color bg: host.background
  function mix(a, b, k) { return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, 1) }
  readonly property color grey: Qt.rgba(fg.r, fg.g, fg.b, 0.5)
  readonly property color s1: Qt.rgba(mix(bg, fg, 0.05).r, mix(bg, fg, 0.05).g, mix(bg, fg, 0.05).b, 0.96)
  readonly property color s2: mix(bg, fg, 0.13)
  readonly property color s3: mix(bg, fg, 0.2)
  readonly property color red: host.palette.red ? Qt.color(host.palette.red) : host.palette.color1 ? Qt.color(host.palette.color1) : host.accent
  readonly property string dotFont: DotMatrix.Palette.fontDot
  readonly property string uiFont: DotMatrix.Palette.fontSans
  readonly property string monoFont: DotMatrix.Palette.fontMono
  readonly property var loc: host.locale

  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: win.open; triggeredOnStart: true; onTriggered: win.now = new Date() }

  function week(d) {
    var tt = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
    tt.setUTCDate(tt.getUTCDate() + 4 - (tt.getUTCDay() || 7))
    return Math.ceil(((tt - Date.UTC(tt.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7)
  }
  function wx(code) {
    var tb = [[[0], "󰖙", "Clear", "Ясно"], [[1, 2], "󰖕", "Partly cloudy", "Облачно"], [[3], "󰖐", "Cloudy", "Пасмурно"],
              [[45, 48], "󰖑", "Fog", "Туман"], [[51, 53, 55, 56, 57], "󰖗", "Drizzle", "Морось"],
              [[61, 63, 65, 66, 67, 80, 81, 82], "󰖖", "Rain", "Дождь"], [[71, 73, 75, 77, 85, 86], "󰖘", "Snow", "Снег"],
              [[95, 96, 99], "󰖓", "Storm", "Гроза"]]
    for (var i = 0; i < tb.length; i++) if (tb[i][0].indexOf(code) !== -1) return { icon: tb[i][1], text: host.tr(tb[i][2], tb[i][3]) }
    return { icon: "󰖐", text: "" }
  }
  function hm(d) { return Qt.formatTime(d, host.value("clock24") !== false ? "HH:mm" : "h:mm ap") }
  function kb(b) { return b >= 1048576 ? (b / 1048576).toFixed(1) : Math.round(b / 1024) }
  function unit(b) { return b >= 1048576 ? "MB/s" : "KB/s" }
  function clockOf(sec) {
    sec = Math.max(0, Math.floor(sec || 0))
    var m = Math.floor(sec / 60), ss = sec % 60
    return m + ":" + (ss < 10 ? "0" : "") + ss
  }
  readonly property var w: host.weather
  readonly property bool wOk: w !== null && w !== undefined && w.temp !== undefined

  // Процессы — только пока открыт.
  property var procs: []
  Process {
    id: psProc
    command: ["bash", "-c", "ps -eo comm=,pcpu= --sort=-pcpu | head -4"]
    stdout: StdioCollector {
      onStreamFinished: {
        var out = []
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var m = lines[i].trim().match(/^(.*\S)\s+([\d.]+)$/)
          if (m) out.push({ name: m[1], cpu: Number(m[2]) })
        }
        win.procs = out
      }
    }
  }
  Timer { interval: 2000; repeat: true; triggeredOnStart: true; running: win.open && win.ids.indexOf("perf") !== -1; onTriggered: if (!psProc.running) psProc.running = true }

  Item {
    id: hoverRoot
    width: win.width
    height: win.height

    // dwell — задержка на полосе; bump — второй заход на полосу за 0.6 с после ухода с неё.
    // full не закрывается уходом курсора (он и так внутри) — кликом по фону или Esc.
    property double leftAt: 0
    HoverHandler {
      onHoveredChanged: {
        if (hovered) {
          leave.stop()
          if (win.open || win.fullscreen) return
          if (!win.bump) { dwell.restart(); return }
          // Вернулся на полосу вскоре после ухода с неё — толчок. Первый подход сверху не считается.
          if (Date.now() - hoverRoot.leftAt < 600) win.host.deckOn = win.name
        } else {
          dwell.stop()
          hoverRoot.leftAt = Date.now()
          if (win.open && !win.full) leave.restart()
        }
      }
    }

    Item {
      id: strip
      anchors.bottom: parent.bottom
      width: parent.width
      height: 2
    }

    Item {
      id: stage
      width: win.width / win.s
      height: win.height / win.s
      scale: win.s
      transformOrigin: Item.TopLeft

      // ── full: на весь экран ──
      Item {
        id: fullView
        visible: win.full && win.t > 0
        anchors.fill: parent
        opacity: win.t
        focus: win.fullOpen
        Keys.onEscapePressed: win.host.deckOn = ""
        Rectangle {
          anchors.fill: parent
          color: "#000000"
          opacity: Math.max(0, Math.min(0.95, Number(win.host.value("deckDim")) || 0.8))
          MouseArea { anchors.fill: parent; onClicked: win.host.deckOn = "" }
        }
        Column {
          anchors.horizontalCenter: parent.horizontalCenter
          y: 90 + (1 - win.t) * 60
          spacing: 36
          Column {
            anchors.horizontalCenter: parent.horizontalCenter
            Num { anchors.horizontalCenter: parent.horizontalCenter; text: win.hm(win.now); font.pixelSize: 180 }
            Lb {
              anchors.horizontalCenter: parent.horizontalCenter
              text: win.loc.toString(win.now, "dddd · d MMMM") + " · " + win.host.tr("week ", "неделя ") + win.week(win.now)
              font.pixelSize: 15
            }
          }
          Flow {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(stage.width - 160, 1500)
            spacing: 24
            Repeater {
              model: win.ids.filter(function(x) { return x !== "clock" })
              Item {
                id: fcell
                required property string modelData
                width: fl.item ? fl.item.width + 52 : 0
                height: win.h + 52
                DeckCard { anchors.fill: parent }
                Loader { id: fl; x: 26; y: 26; sourceComponent: ({ weather: weatherC, perf: perfC, net: netC, media: mediaC })[fcell.modelData] }
              }
            }
          }
        }
        Lb {
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 40
          text: win.host.tr("Esc · click outside — close", "Esc · клик мимо — закрыть")
        }
      }

      Item {
        id: panel
        visible: !win.full
        anchors.horizontalCenter: parent.horizontalCenter
        y: (1 - win.t) * (height + 14)
        width: (win.layout === "compact" ? compactRow.width : row.width) + 52
        height: (win.layout === "compact" ? compactRow.height : win.h) + 52
        opacity: win.t

        Rectangle {
          visible: String(win.host.value("deckCards")) !== "style"
          anchors.fill: parent
          radius: 40
          color: win.s1
          border { width: 1; color: win.s2 }
        }
        StyleCard {
          visible: String(win.host.value("deckCards")) === "style" && win.host.deskStyle.card
          anchors.fill: parent
          style: win.host.deskStyle
          glassLayer: "omarchy-deck"
          tape: false
          radius: 40
        }
        Rectangle {
          visible: String(win.host.value("deckCards")) === "style" && !win.host.deskStyle.card
          anchors.fill: parent
          radius: 40
          color: win.host.deskStyle.color
          border.width: 1
          border.color: win.host.deskStyle.borderWidth > 0 ? win.host.deskStyle.borderColor : win.s2
        }

        Row {
          id: row
          visible: win.layout === "panel"
          x: 26; y: 26
          spacing: 16
          Repeater {
            model: win.ids
            Row {
              id: cell
              required property string modelData
              required property int index
              spacing: 16
              // Между секциями — столбик точек.
              Column {
                visible: cell.index > 0
                spacing: 6
                Repeater { model: Math.floor(win.h / 10); Rectangle { width: 3; height: 3; radius: 1.5; color: win.s3 } }
              }
              Loader { sourceComponent: ({ clock: clockC, weather: weatherC, perf: perfC, net: netC, media: mediaC })[cell.modelData] }
            }
          }
        }
        // compact: тонкая полоска — время, три мини-кольца, трек с кнопкой, скорость сети.
        Row {
          id: compactRow
          visible: win.layout === "compact"
          x: 26; y: 26
          height: 84
          spacing: 26
          readonly property var p: win.host.player
          Column {
            anchors.verticalCenter: parent.verticalCenter
            Num { text: win.hm(win.now); font.pixelSize: 54 }
            Lb { text: win.loc.toString(win.now, "ddd · d MMM") }
          }
          Repeater {
            model: [
              { f: win.host.cpu, v: Math.round(win.host.cpu * 100), l: "cpu" },
              { f: win.host.mem, v: Math.round(win.host.mem * 100), l: "mem" },
              { f: Math.min(1, win.host.temp / 100), v: Math.round(win.host.temp), l: "°c" }
            ]
            Item {
              required property var modelData
              anchors.verticalCenter: parent.verticalCenter
              width: 74; height: 74
              DotRing { anchors.fill: parent; n: 24; dot: 4; inset: 6; f: parent.modelData.f; on: win.fg; off: win.s3 }
              Column {
                anchors.centerIn: parent
                Num { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.modelData.v; font.pixelSize: 22 }
                Lb { anchors.horizontalCenter: parent.horizontalCenter; text: parent.parent.modelData.l; font.pixelSize: 9 }
              }
            }
          }
          Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: 44; height: 44; radius: 22
              color: win.red
              Text { anchors.centerIn: parent; text: win.host.playing ? "󰏤" : "󰐊"; font.family: win.host.iconFamily; font.pixelSize: 18; color: "#ffffff" }
              MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { var pl = compactRow.p; if (pl && pl.canTogglePlaying) pl.togglePlaying() } }
            }
            Column {
              anchors.verticalCenter: parent.verticalCenter
              width: 200
              Text {
                width: parent.width; elide: Text.ElideRight
                text: compactRow.p && compactRow.p.trackTitle ? compactRow.p.trackTitle : win.host.tr("Nothing on", "Ничего не играет")
                font { family: win.uiFont; pixelSize: 16; weight: Font.DemiBold }
                color: win.fg
              }
              Lb { width: parent.width; elide: Text.ElideRight; text: compactRow.p ? String(compactRow.p.trackArtist || compactRow.p.identity || "") : "" }
            }
          }
          Column {
            anchors.verticalCenter: parent.verticalCenter
            Lb { text: "↓ " + win.kb(win.host.rxRate) + " " + win.unit(win.host.rxRate); color: win.fg }
            Lb { text: "↑ " + win.kb(win.host.txRate) + " " + win.unit(win.host.txRate) }
          }
        }
      }
    }
  }

  // ── Секции ──
  // Часы: день недели, время, дата · неделя; световой день точками от восхода до заката.
  Component {
    id: clockC
    Column {
      width: 300
      height: win.h
      Lb { text: win.loc.standaloneDayName(win.now.getDay()) }
      Num { topPadding: 6; text: win.hm(win.now); font.pixelSize: 84 }
      Lb { topPadding: 6; text: win.loc.toString(win.now, "d MMMM") + " · " + win.host.tr("week ", "неделя ") + win.week(win.now) }
      Item { width: 1; height: 34 }
      readonly property real rise: win.w && win.w.sunrise ? new Date(win.w.sunrise).getTime() : NaN
      readonly property real set: win.w && win.w.sunset ? new Date(win.w.sunset).getTime() : NaN
      readonly property real light: isFinite(rise) && isFinite(set) && set > rise
        ? Math.max(0, Math.min(1, (win.now.getTime() - rise) / (set - rise)))
        : (win.now.getHours() * 60 + win.now.getMinutes()) / 1440
      DotSeg { width: parent.width; n: 30; f: parent.light; on: win.fg; off: win.s3 }
      Item { width: 1; height: 16 }
      Row {
        width: parent.width
        visible: isFinite(parent.rise)
        Lb { width: parent.width / 2; text: "󰖜  " + (isFinite(parent.parent.rise) ? win.hm(new Date(parent.parent.rise)) : "") }
        Lb { width: parent.width / 2; horizontalAlignment: Text.AlignRight; text: "󰖛  " + (isFinite(parent.parent.set) ? win.hm(new Date(parent.parent.set)) : "") }
      }
    }
  }
  // Погода: сейчас + прогноз на 4 дня.
  Component {
    id: weatherC
    Column {
      width: 340
      height: win.h
      Lb { text: win.wOk ? win.wx(win.w.code).text : win.host.tr("weather", "погода") }
      Row {
        topPadding: 6
        spacing: 14
        Text { anchors.verticalCenter: parent.verticalCenter; text: win.wOk ? win.wx(win.w.code).icon : "󰖐"; font.family: win.host.iconFamily; font.pixelSize: 54; color: win.fg }
        Num { anchors.verticalCenter: parent.verticalCenter; text: win.wOk ? Math.round(win.w.temp) + "°" : "--"; font.pixelSize: 84 }
      }
      Lb {
        topPadding: 4
        text: win.wOk ? win.host.tr("feels ", "ощущается ") + Math.round(win.w.feels) + "° · " + Math.round(win.w.wind) + win.host.tr(" km/h", " км/ч")
          : win.host.tr("set weatherCity in Customizer", "задай weatherCity в Customizer")
      }
      Item { width: 1; height: 22 }
      Row {
        visible: win.wOk && win.w.days !== undefined
        spacing: 0
        Repeater {
          model: win.wOk && win.w.days ? win.w.days.slice(0, 4) : []
          Column {
            required property var modelData
            width: 85
            spacing: 6
            Lb { anchors.horizontalCenter: parent.horizontalCenter; text: win.loc.dayName(new Date(parent.modelData.date).getDay(), Locale.ShortFormat) }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: win.wx(parent.modelData.code).icon; font.family: win.host.iconFamily; font.pixelSize: 22; color: win.grey }
            Lb { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(parent.modelData.max) + "°"; color: win.fg }
            Lb { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(parent.modelData.min) + "°" }
          }
        }
      }
    }
  }
  // Производительность: три кольца (CPU, память, температура), процессы и матрица CPU за минуту.
  Component {
    id: perfC
    Column {
      width: 470
      height: win.h
      spacing: 14
      Row {
        spacing: 22
        Repeater {
          model: [
            { f: win.host.cpu, v: Math.round(win.host.cpu * 100), l: "cpu · " + Math.round(win.host.temp) + "°", hot: win.host.cpu > 0.9 },
            { f: win.host.mem, v: Math.round(win.host.mem * 100), l: "mem · " + win.host.memUsedGb.toFixed(1) + "G", hot: win.host.mem > 0.9 },
            { f: Math.min(1, win.host.temp / 100), v: Math.round(win.host.temp), l: "temp °", hot: win.host.temp >= 85 }
          ]
          Column {
            required property var modelData
            spacing: 6
            Item {
              width: 92; height: 92
              DotRing { anchors.fill: parent; n: 30; dot: 5; inset: 8; f: parent.parent.modelData.f; on: parent.parent.modelData.hot ? win.red : win.fg; off: win.s3 }
              Num { anchors.centerIn: parent; text: parent.parent.modelData.v; font.pixelSize: 30; color: parent.parent.modelData.hot ? win.red : win.fg }
            }
            Lb { anchors.horizontalCenter: parent.horizontalCenter; text: parent.modelData.l }
          }
        }
      }
      Row {
        spacing: 24
        Column {
          width: 210
          spacing: 5
          Lb { text: win.host.tr("processes", "процессы") }
          Repeater {
            model: win.procs
            Row {
              required property var modelData
              width: 210
              Lb { width: 110; elide: Text.ElideRight; text: parent.modelData.name; color: win.fg }
              Lb { width: 44; horizontalAlignment: Text.AlignRight; text: Math.round(parent.modelData.cpu) + "%" }
              Item { width: 8; height: 1 }
              DotSeg { anchors.verticalCenter: parent.verticalCenter; width: 48; n: 6; dot: 4; f: parent.modelData.cpu / 100; on: win.fg; off: win.s3 }
            }
          }
        }
        Column {
          spacing: 8
          Lb { text: "cpu · 60 s" }
          Grid {
            id: spark
            columns: 24
            spacing: 3
            readonly property var hist: win.host.cpuHistory.slice(-24)
            Repeater {
              model: 24 * 6
              Rectangle {
                required property int index
                readonly property int col: index % 24
                readonly property int up: 6 - Math.floor(index / 24)
                readonly property var v: spark.hist[col - 24 + spark.hist.length]
                readonly property int hh: v === undefined ? 0 : Math.round(1 + 4 * v)
                width: 5; height: 5; radius: 2.5
                color: up === hh ? win.fg : up < hh ? win.grey : win.s2
              }
            }
          }
        }
      }
    }
  }
  // Сеть: скорость вниз / вверх и матрица приёма.
  Component {
    id: netC
    Column {
      width: 230
      height: win.h
      Lb { text: "net · " + (win.host.netIface || "offline") }
      Item { width: 1; height: 10 }
      Repeater {
        model: [{ a: "↓", v: win.host.rxRate }, { a: "↑", v: win.host.txRate }]
        Row {
          required property var modelData
          spacing: 10
          Num { text: parent.modelData.a; font.pixelSize: 34; color: win.grey }
          Num { text: win.kb(parent.modelData.v); font.pixelSize: 44 }
          Lb { anchors.bottom: parent.bottom; anchors.bottomMargin: 8; text: win.unit(parent.modelData.v) }
        }
      }
      Item { width: 1; height: 12 }
      Grid {
        id: netGrid
        columns: 22
        spacing: 3
        readonly property var hist: win.host.rxHistory.slice(-22)
        readonly property real peak: Math.max(1024, Math.max.apply(null, hist.length ? hist : [0]))
        Repeater {
          model: 22 * 6
          Rectangle {
            required property int index
            readonly property int col: index % 22
            readonly property int up: 6 - Math.floor(index / 22)
            readonly property var v: netGrid.hist[col - 22 + netGrid.hist.length]
            readonly property int hh: v === undefined ? 0 : Math.round(v / netGrid.peak * 6)
            width: 7; height: 7; radius: 3.5
            color: up <= hh ? (up === hh ? win.fg : win.grey) : win.s2
          }
        }
      }
    }
  }
  // Плеер: обложка точками, трек, прогресс точками, время и кнопки.
  Component {
    id: mediaC
    Column {
      width: 330
      height: win.h
      readonly property var p: win.host.player
      Lb { width: parent.width; elide: Text.ElideRight; text: parent.p ? (parent.p.identity || "player") : win.host.tr("silence", "тишина") }
      Item { width: 1; height: 10 }
      Row {
        spacing: 16
        DotArt {
          width: 96; height: 96
          step: 5
          url: parent.parent.p ? String(parent.parent.p.trackArtUrl || "") : ""
          spinning: win.open && win.host.playing
          off: win.s3
        }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          width: 218
          Text {
            width: parent.width
            maximumLineCount: 2
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            text: parent.parent.parent.p && parent.parent.parent.p.trackTitle ? parent.parent.parent.p.trackTitle : win.host.tr("Nothing on", "Ничего не играет")
            font { family: win.uiFont; pixelSize: 20; weight: Font.DemiBold }
            color: win.fg
          }
          Text {
            width: parent.width
            elide: Text.ElideRight
            text: parent.parent.parent.p ? String(parent.parent.parent.p.trackArtist || "") : ""
            font { family: win.uiFont; pixelSize: 14 }
            color: win.grey
          }
        }
      }
      Item { width: 1; height: 16 }
      DotSeg {
        width: parent.width
        n: 28
        readonly property var pl: parent.p
        f: pl && pl.lengthSupported && pl.length > 0 ? pl.position / pl.length : 0
        on: win.fg; off: win.s3
      }
      Item { width: 1; height: 6 }
      Row {
        width: parent.width
        readonly property var pl: parent.p
        Lb { width: parent.width / 2; text: parent.pl ? win.clockOf(parent.pl.position) : "" }
        Lb { width: parent.width / 2; horizontalAlignment: Text.AlignRight; text: parent.pl && parent.pl.lengthSupported ? win.clockOf(parent.pl.length) : "" }
      }
      Item { width: 1; height: 4 }
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 22
        readonly property var pl: parent.p
        Icon { anchors.verticalCenter: parent.verticalCenter; text: "󰒮"; onClicked: if (parent.pl && parent.pl.canGoPrevious) parent.pl.previous() }
        Rectangle {
          width: 46; height: 46; radius: 23
          color: win.red
          Text { anchors.centerIn: parent; text: win.host.playing ? "󰏤" : "󰐊"; font.family: win.host.iconFamily; font.pixelSize: 20; color: "#ffffff" }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: { var pl = parent.parent.pl; if (pl && pl.canTogglePlaying) pl.togglePlaying() }
          }
        }
        Icon { anchors.verticalCenter: parent.verticalCenter; text: "󰒭"; onClicked: if (parent.pl && parent.pl.canGoNext) parent.pl.next() }
      }
    }
  }

  // Подложка карточки секции в full: плоская glyph или материал стиля (deckCards).
  component DeckCard: Item {
    Rectangle {
      visible: String(win.host.value("deckCards")) !== "style"
      anchors.fill: parent
      radius: 40
      color: win.s1
      border { width: 1; color: win.s2 }
    }
    StyleCard {
      visible: String(win.host.value("deckCards")) === "style" && win.host.deskStyle.card
      anchors.fill: parent
      style: win.host.deskStyle
      glassLayer: "omarchy-deck"
      tape: false
      radius: 40
    }
    Rectangle {
      visible: String(win.host.value("deckCards")) === "style" && !win.host.deskStyle.card
      anchors.fill: parent
      radius: 40
      color: win.host.deskStyle.color
      border.width: 1
      border.color: win.host.deskStyle.borderWidth > 0 ? win.host.deskStyle.borderColor : win.s2
    }
  }
  component Num: Text {
    font.family: win.dotFont
    color: win.fg
  }
  component Lb: Text {
    font { family: win.monoFont; pixelSize: 12; letterSpacing: 2; capitalization: Font.AllUppercase }
    color: win.grey
  }
  component Icon: Text {
    signal clicked()
    font.family: win.host.iconFamily
    font.pixelSize: 20
    color: win.grey
    MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
  }
}

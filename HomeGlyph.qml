import QtQuick
import QtQuick.Effects
import "dotmatrix" as DotMatrix

// Раскладка домашнего экрана «glyph» — по мотивам glyph-rice (вид повторён, код свой): слева огромные
// точечные часы, «день · дата · неделя», приветствие в две строки (имя — серым) и строка с погодой и
// батареей; справа бенто 3×3: ячейки 220, зазор 20, квадрат со скруглением 40 или круг.
// Набор и порядок плиток — homeWidgets (через запятую): weather calendar cpu ram battery temp disk cava
// (1 клетка), player network (2), system (3). Не влезла в ряд — со следующего, в три ряда не влезла — нет.
// Вся сцена нарисована в сетке 1920×1080 и масштабируется под экран (homeScale — множитель сверху).
Item {
  id: g

  required property var host          // Widgets.qml
  required property var homeScreen    // HomeScreen.qml (now, hello, userName, shown, rate())

  readonly property real s: Math.min(width / 1920, height / 1080) * Math.max(0.4, Math.min(2, Number(host.value("homeScale")) || 1))

  // ── Цвета и шрифты ──
  readonly property bool styled: String(host.value("homeCards")) === "style"
  readonly property color fg: host.foreground
  readonly property color bg: host.background
  function mix(a, b, k) { return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, 1) }
  readonly property color grey: Qt.rgba(fg.r, fg.g, fg.b, 0.5)
  readonly property color s1: Qt.rgba(mix(bg, fg, 0.05).r, mix(bg, fg, 0.05).g, mix(bg, fg, 0.05).b, 0.94)
  readonly property color s2: mix(bg, fg, 0.13)
  readonly property color s3: mix(bg, fg, 0.2)
  readonly property color red: host.palette.red ? Qt.color(host.palette.red) : host.palette.color1 ? Qt.color(host.palette.color1) : host.accent
  readonly property string dotFont: DotMatrix.Palette.fontDot
  readonly property string uiFont: DotMatrix.Palette.fontSans
  readonly property string monoFont: DotMatrix.Palette.fontMono
  readonly property var en: Qt.locale("en_US")
  readonly property var loc: host.locale

  function week(d) {
    var t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
    t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7))
    return Math.ceil(((t - Date.UTC(t.getUTCFullYear(), 0, 1)) / 86400000 + 1) / 7)
  }
  function weather(code) {
    var t = [[[0], "󰖙", "Clear", "Ясно"], [[1, 2], "󰖕", "Partly cloudy", "Облачно"], [[3], "󰖐", "Cloudy", "Пасмурно"],
             [[45, 48], "󰖑", "Fog", "Туман"], [[51, 53, 55, 56, 57], "󰖗", "Drizzle", "Морось"],
             [[61, 63, 65, 66, 67, 80, 81, 82], "󰖖", "Rain", "Дождь"], [[71, 73, 75, 77, 85, 86], "󰖘", "Snow", "Снег"],
             [[95, 96, 99], "󰖓", "Storm", "Гроза"]]
    for (var i = 0; i < t.length; i++) if (t[i][0].indexOf(code) !== -1) return { icon: t[i][1], text: host.tr(t[i][2], t[i][3]) }
    return { icon: "󰖐", text: "" }
  }
  readonly property var w: host.weather
  readonly property bool wOk: w !== null && w !== undefined && w.temp !== undefined

  // Зона кликов для маски окна — бенто справа (в координатах экрана).
  readonly property Item hit: hitArea
  Item {
    id: hitArea
    x: (stage.width - 780) * g.s
    y: 150 * g.s
    width: 720 * g.s
    height: 700 * g.s
  }

  // Мигающее двоеточие — два кадра в секунду.
  property bool blinkDim: false
  Timer { running: g.homeScreen.shown && g.host.value("homeBlink") === true; interval: 500; repeat: true; onTriggered: g.blinkDim = !g.blinkDim }

  Item {
    id: stage
    width: g.width / g.s
    height: g.height / g.s
    scale: g.s
    transformOrigin: Item.TopLeft

    // ── Слева: часы, дата, приветствие, мета ──
    Row {
      x: 182; y: 150
      Num { text: Qt.formatTime(g.homeScreen.now, g.host.value("clock24") !== false ? "HH" : "h"); font.pixelSize: 300 }
      Num { text: ":"; font.pixelSize: 300; opacity: g.blinkDim ? 0.2 : 1 }
      Num { text: Qt.formatTime(g.homeScreen.now, "mm"); font.pixelSize: 300 }
    }
    Lb {
      visible: g.host.value("homeDate") !== false
      x: 190; y: 448; px: 14
      text: g.loc.toString(g.homeScreen.now, "dddd · d MMMM") + " · " + g.host.tr("week ", "неделя ") + g.week(g.homeScreen.now)
    }
    Text {
      visible: g.host.value("homeGreeting") !== false
      x: 188; y: 560
      textFormat: Text.StyledText
      text: g.homeScreen.hello + ",<br><font color=\"" + g.grey + "\">" + g.homeScreen.userName.replace(/&/g, "&amp;").replace(/</g, "&lt;") + ".</font>"
      font { family: g.uiFont; pixelSize: 54; weight: Font.Light; letterSpacing: -1 }
      lineHeight: 1.1
      color: g.fg
    }
    Row {
      visible: g.host.value("homeMeta") !== false
      x: 190; y: 700
      spacing: 28
      Meta { visible: g.wOk; icon: g.wOk ? g.weather(g.w.code).icon : ""; text: g.wOk ? Math.round(g.w.temp) + "° " + g.weather(g.w.code).text : "" }
      Meta {
        visible: g.host.battery >= 0
        icon: g.host.batteryStatus === "Charging" ? "󰂄" : "󰁹"
        text: g.host.battery + "% " + (g.host.batteryStatus === "Charging" ? g.host.tr("charging", "заряжается") : g.host.tr("battery", "батарея"))
      }
      Meta { visible: g.host.netIface !== ""; icon: "󰖩"; text: g.host.netIface }
    }

    // ── Справа: бенто ──
    readonly property var spans: ({ weather: 1, calendar: 1, cpu: 1, ram: 1, battery: 1, temp: 1, disk: 1, cava: 1, player: 2, network: 2, system: 3 })
    Repeater {
      model: {
        var ids = String(g.host.value("homeWidgets") || "").split(/[\s,]+/).filter(function(x) { return x !== "" })
        var out = [], r = 0, c = 0
        for (var i = 0; i < ids.length; i++) {
          var span = stage.spans[ids[i]]
          if (!span) continue
          if (c + span > 3) { r++; c = 0 }
          if (r > 2) break
          out.push({ id: ids[i], x: c * 240, y: 150 + r * 240 })
          c += span
        }
        return out
      }
      delegate: Loader {
        required property var modelData
        x: stage.width - 780 + modelData.x
        y: modelData.y
        sourceComponent: ({ weather: weatherW, calendar: calendarW, cpu: cpuW, ram: ramW, battery: batteryW, temp: tempW,
                            disk: diskW, cava: cavaW, player: playerW, network: networkW, system: systemW })[modelData.id] || null
      }
    }
  }

  // ── Плитки ──
  Component {
    id: weatherW
    Card {
      round: true
      Column {
        anchors.centerIn: parent
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: g.wOk ? g.weather(g.w.code).icon : "󰖐"
          font.family: g.host.iconFamily
          font.pixelSize: 64
          color: g.fg
        }
        Num { anchors.horizontalCenter: parent.horizontalCenter; text: g.wOk ? Math.round(g.w.temp) + "°" : "--"; font.pixelSize: 62 }
        Lb {
          anchors.horizontalCenter: parent.horizontalCenter
          topPadding: 8
          width: Math.min(implicitWidth, 160)
          elide: Text.ElideRight
          text: g.wOk ? g.weather(g.w.code).text + " · " + Math.round(g.w.min) + "°/" + Math.round(g.w.max) + "°"
            : g.host.tr("set weatherCity", "задай weatherCity")
        }
      }
    }
  }
  Component {
    id: calendarW
    Card {
      Column {
        x: 24; y: 24
        width: parent.width - 48
        Lb { text: g.loc.standaloneMonthName(g.homeScreen.now.getMonth()) }
        Num { topPadding: 8; text: g.homeScreen.now.getDate(); font.pixelSize: 112 }
        Row {
          width: parent.width
          topPadding: 10
          Repeater {
            model: 7
            Text {
              required property int index
              readonly property bool today: (g.homeScreen.now.getDay() + 6) % 7 === index
              width: parent.width / 7
              horizontalAlignment: Text.AlignHCenter
              text: g.loc.dayName((index + 1) % 7, Locale.NarrowFormat).toUpperCase()
              font { family: g.monoFont; pixelSize: 11 }
              color: today ? g.fg : g.grey
              Rectangle { visible: parent.today; anchors { bottom: parent.bottom; bottomMargin: -4; horizontalCenter: parent.horizontalCenter } width: 10; height: 2; color: g.fg }
            }
          }
        }
      }
    }
  }
  Component { id: cpuW; RingCard { f: g.host.cpu; value: Math.round(g.host.cpu * 100); label: "cpu %" } }
  Component { id: ramW; RingCard { f: g.host.mem; value: Math.round(g.host.mem * 100); label: "ram %" } }
  Component { id: tempW; RingCard { f: Math.min(1, g.host.temp / 100); value: Math.round(g.host.temp) + "°"; label: "cpu temp"; on: g.host.temp >= 85 ? g.red : g.fg } }
  Component { id: diskW; RingCard { f: g.host.disk; value: Math.round(g.host.disk * 100); label: "disk %" } }
  Component {
    id: batteryW
    RingCard {
      f: Math.max(0, g.host.battery) / 100
      value: g.host.battery >= 0 ? g.host.battery : "AC"
      label: g.host.batteryStatus === "Charging" ? "charging" : "battery"
      on: g.host.batteryStatus !== "Charging" && g.host.battery >= 0 && g.host.battery < 15 ? g.red : g.fg
    }
  }
  Component {
    id: playerW
    Card {
      span: 2
      readonly property var p: g.host.player
      DotArt {
        id: art
        x: 28
        anchors.verticalCenter: parent.verticalCenter
        width: 164; height: 164
        url: parent.p ? String(parent.p.trackArtUrl || "") : ""
        spinning: g.homeScreen.shown && g.host.playing
        off: g.s3
      }
      Column {
        anchors { left: art.right; leftMargin: 26; right: parent.right; rightMargin: 28; verticalCenter: parent.verticalCenter }
        Lb { width: parent.width; elide: Text.ElideRight; text: "now playing · " + (parent.parent.p ? (parent.parent.p.identity || "") : "silence") }
        Text {
          width: parent.width
          topPadding: 10
          elide: Text.ElideRight
          text: parent.parent.p && parent.parent.p.trackTitle ? parent.parent.p.trackTitle : g.host.tr("Nothing on", "Тишина")
          textFormat: Text.PlainText
          font { family: g.uiFont; pixelSize: 26; weight: Font.DemiBold }
          color: g.fg
        }
        Text {
          width: parent.width
          elide: Text.ElideRight
          text: parent.parent.p ? String(parent.parent.p.trackArtist || "") : ""
          textFormat: Text.PlainText
          font { family: g.uiFont; pixelSize: 15 }
          color: g.grey
        }
        Item { width: 1; height: 18 }
        DotSeg {
          width: parent.width
          on: g.fg
          off: g.s3
          readonly property var pl: parent.parent.p
          f: pl && pl.lengthSupported && pl.length > 0 ? pl.position / pl.length : 0
        }
        Item { width: 1; height: 14 }
        Row {
          spacing: 18
          readonly property var pl: parent.parent.p
          Glyph { anchors.verticalCenter: parent.verticalCenter; text: "󰒮"; onClicked: if (parent.pl && parent.pl.canGoPrevious) parent.pl.previous() }
          Rectangle {
            width: 52; height: 52; radius: 26
            color: g.red
            Text {
              anchors.centerIn: parent
              text: g.host.playing ? "󰏤" : "󰐊"
              font.family: g.host.iconFamily
              font.pixelSize: 24
              color: "#ffffff"
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: { var pl = parent.parent.pl; if (pl && pl.canTogglePlaying) pl.togglePlaying() }
            }
          }
          Glyph { anchors.verticalCenter: parent.verticalCenter; text: "󰒭"; onClicked: if (parent.pl && parent.pl.canGoNext) parent.pl.next() }
        }
      }
    }
  }
  Component {
    id: networkW
    Card {
      span: 2
      Column {
        x: 34
        anchors.verticalCenter: parent.verticalCenter
        spacing: 18
        Lb { text: "network · " + (g.host.netIface || "offline") }
        Row {
          spacing: 40
          Stat { label: "down"; value: g.homeScreen.rate(g.host.rxRate) }
          Stat { label: "up"; value: g.homeScreen.rate(g.host.txRate) }
        }
      }
    }
  }
  Component {
    id: systemW
    Card {
      span: 3
      Grid {
        x: 34
        anchors.verticalCenter: parent.verticalCenter
        columns: 2
        columnSpacing: 10
        rowSpacing: 22
        Stat { label: "cpu"; value: Math.round(g.host.cpu * 100) + "%" }
        Stat { label: "mem"; value: g.host.memUsedGb.toFixed(1) + "G" }
        Stat { label: "temp"; value: Math.round(g.host.temp) + "°" }
        Stat { label: "disk"; value: Math.round(g.host.disk * 100) + "%" }
      }
      Column {
        x: 344
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - 34
        spacing: 12
        Lb { text: "cpu · 60 s" }
        // Матрица 34×8: верхняя точка столбца — цветом текста, под ней серые, выше — погасшие.
        Grid {
          id: spark
          width: parent.width
          columns: 34
          spacing: 4
          readonly property real d: (width - 33 * spacing) / 34
          readonly property var hist: g.host.cpuHistory.slice(-34)
          Repeater {
            model: 34 * 8
            Rectangle {
              required property int index
              readonly property int col: index % 34
              readonly property int up: 8 - Math.floor(index / 34)
              readonly property var v: spark.hist[col - 34 + spark.hist.length]
              readonly property int h: v === undefined ? 0 : Math.round(1 + 6 * v)
              width: spark.d; height: spark.d; radius: spark.d / 2
              color: up === h ? g.fg : up < h ? g.grey : g.s2
            }
          }
        }
      }
    }
  }
  // cava точками в круге: бас в центре, к краям верхи, столбики растут от середины вверх и вниз.
  Component {
    id: cavaW
    Card {
      round: true
      Grid {
        anchors.centerIn: parent
        columns: 15
        spacing: 4
        Repeater {
          model: 15 * 15
          Rectangle {
            required property int index
            readonly property int cx: index % 15 - 7
            readonly property int cy: Math.floor(index / 15) - 7
            readonly property int half: Math.floor(Math.sqrt(7.5 * 7.5 - cx * cx))
            readonly property var lv: g.host.levels
            readonly property real v: lv.length > 0 ? lv[Math.min(lv.length - 1, Math.round(Math.abs(cx) / 7 * (lv.length - 1) * 0.6))] : 0
            width: 8; height: 8; radius: 4
            color: Math.abs(cy) > half ? "transparent" : Math.abs(cy) < v * (half + 1) ? g.fg : g.s3
          }
        }
      }
    }
  }

  // ── Строительные блоки ──
  component Num: Text {
    font.family: g.dotFont
    color: g.fg
  }
  component Lb: Text {
    property int px: 12
    font { family: g.monoFont; pixelSize: px; letterSpacing: px * 0.18; capitalization: Font.AllUppercase }
    color: g.grey
  }
  component Meta: Row {
    property string icon
    property string text
    spacing: 10
    Text { anchors.verticalCenter: parent.verticalCenter; text: parent.icon; font.family: g.host.iconFamily; font.pixelSize: 16; color: g.fg }
    Lb { anchors.verticalCenter: parent.verticalCenter; text: parent.text }
  }
  component Stat: Column {
    property string label
    property string value
    width: 130
    Lb { text: parent.label }
    Num { topPadding: 6; text: parent.value; font.pixelSize: 40 }
  }
  component Glyph: Text {
    signal clicked()
    font.family: g.host.iconFamily
    font.pixelSize: 22
    color: g.grey
    MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
  }
  // Подложка плитки: свой плоский вид glyph (s1 + контур s2) или материал стиля (homeCards = style).
  component Card: Item {
    property int span: 1
    property bool round: false
    width: span * 220 + (span - 1) * 20
    height: 220
    readonly property real r: round ? 110 : 40
    Rectangle {
      visible: !g.styled
      anchors.fill: parent
      radius: parent.r
      color: g.s1
      border { width: 1; color: g.s2 }
    }
    StyleCard {
      visible: g.styled && g.host.deskStyle.card
      anchors.fill: parent
      style: g.host.deskStyle
      tape: false
      radius: parent.r
    }
    Rectangle {
      visible: g.styled && !g.host.deskStyle.card
      anchors.fill: parent
      radius: parent.r
      color: g.host.deskStyle.color
      border.width: 1
      border.color: g.host.deskStyle.borderWidth > 0 ? g.host.deskStyle.borderColor : g.s2
    }
  }
  // Круглая плитка: кольцо из точек горит долей f, в центре число и подпись.
  component RingCard: Card {
    id: rc
    property real f: 0
    property string value
    property string label
    property color on: g.fg
    round: true
    DotRing { anchors.fill: parent; f: rc.f; on: rc.on; off: g.s3 }
    Column {
      anchors.centerIn: parent
      Num { anchors.horizontalCenter: parent.horizontalCenter; text: rc.value; font.pixelSize: 68; color: rc.on }
      Lb { anchors.horizontalCenter: parent.horizontalCenter; topPadding: 6; text: rc.label }
    }
  }
}

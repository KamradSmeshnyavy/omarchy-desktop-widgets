import QtQuick

// Карточка календаря и погоды surface (по мотивам hub/CalendarWeatherCard.qml surface-dots, snes19xx; README разрешает
// брать со ссылкой; код свой). Два вида:
//   малый (big: false, Hub в Super+M) — «SUN», крупное число и строка погоды слева, месяц сеткой справа;
//   большой (big: true, дашборд) — «SUNDAY», огромное число, справа сверху значок погоды, температура и подпись,
//   ниже — «NOVEMBER 2026» и сетка месяца на всю ширину; сегодня — кружок акцентом.
Rectangle {
  id: cal
  required property var host
  property bool live: true
  property bool big: false
  property color card
  property color fg
  property color text2
  property color acc
  property color onAcc
  property string font
  property string icons

  radius: big ? 10 : 16
  color: card

  property date now: new Date()
  Timer { interval: 60000; repeat: true; running: cal.live; onTriggered: cal.now = new Date() }
  onLiveChanged: if (live) now = new Date()
  readonly property var w: host.weather
  readonly property bool hasW: !!w && w.error === undefined && w.temp !== undefined
  readonly property string unit: String(host.value("weatherUnits")) === "fahrenheit" ? "°F" : "°"
  function wx(code) {
    var t = [[[0], "\u{F0599}", "Clear sky"], [[1, 2], "\u{F0595}", "Partly cloudy"], [[3], "\u{F0590}", "Overcast clouds"],
             [[45, 48], "\u{F0591}", "Fog"], [[51, 53, 55, 56, 57], "\u{F0597}", "Drizzle"],
             [[61, 63, 65, 66, 67, 80, 81, 82], "\u{F0596}", "Rain"], [[71, 73, 75, 77, 85, 86], "\u{F0598}", "Snow"],
             [[95, 96, 99], "\u{F0593}", "Thunderstorm"]]
    for (var i = 0; i < t.length; i++) if (t[i][0].indexOf(code) !== -1) return t[i]
    return [[], "\u{F0590}", ""]
  }

  // сетка месяца (неделя с воскресенья, как у него)
  component Month: Grid {
    id: g
    property real cw: 13
    property real ch: 11
    property real px: 7
    columns: 7
    columnSpacing: 2; rowSpacing: 1
    readonly property int lead: new Date(cal.now.getFullYear(), cal.now.getMonth(), 1).getDay()
    readonly property int days: new Date(cal.now.getFullYear(), cal.now.getMonth() + 1, 0).getDate()
    Repeater {
      model: ["S", "M", "T", "W", "T", "F", "S"]
      Text { required property var modelData; width: g.cw; horizontalAlignment: Text.AlignHCenter; text: modelData; font.family: cal.font; font.pixelSize: g.px; color: cal.text2 }
    }
    Repeater {
      model: g.lead + g.days
      Rectangle {
        required property int index
        readonly property int d: index - g.lead + 1
        readonly property bool today: d === cal.now.getDate()
        width: g.cw; height: g.ch; radius: Math.min(width, height) / 2
        color: today ? cal.acc : "transparent"
        Text {
          anchors.centerIn: parent
          visible: parent.d > 0
          text: parent.d
          font.family: cal.font; font.pixelSize: g.px; font.weight: parent.today ? 800 : 500
          color: parent.today ? cal.onAcc : cal.fg
        }
      }
    }
  }

  // ── малый ──
  Column {
    visible: !cal.big
    x: 14; y: 10
    Text { text: Qt.formatDate(cal.now, "ddd").toUpperCase(); font.family: cal.font; font.pixelSize: 15; font.weight: 600; color: cal.fg }
    Text { text: Qt.formatDate(cal.now, "d"); font.family: cal.font; font.pixelSize: 38; font.weight: 800; color: cal.fg; lineHeight: 0.9 }
    Row {
      spacing: 4
      visible: cal.hasW
      Text { text: cal.hasW ? cal.wx(cal.w.code)[1] : ""; font.family: cal.icons; font.pixelSize: 11; color: cal.text2; anchors.verticalCenter: parent.verticalCenter }
      Text { text: cal.hasW ? Math.round(cal.w.temp) + cal.unit + " • " + cal.wx(cal.w.code)[2] : ""; font.family: cal.font; font.pixelSize: 9; color: cal.text2; anchors.verticalCenter: parent.verticalCenter }
    }
  }
  Column {
    visible: !cal.big
    anchors.right: parent.right; anchors.rightMargin: 12
    y: 8
    spacing: 2
    Text { anchors.right: parent.right; text: Qt.formatDate(cal.now, "MMM").toUpperCase(); font.family: cal.font; font.pixelSize: 9; font.weight: 800; color: cal.fg; font.letterSpacing: 1 }
    Month {}
  }

  // ── большой ──
  Item {
    visible: cal.big
    anchors.fill: parent
    anchors.margins: 14
    Column {
      Text { text: Qt.formatDate(cal.now, "dddd").toUpperCase(); font.family: cal.font; font.pixelSize: 9; font.weight: 700; font.letterSpacing: 1.2; color: cal.text2 }
      Text { text: Qt.formatDate(cal.now, "d"); font.family: cal.font; font.pixelSize: 54; font.weight: 800; color: cal.fg; lineHeight: 0.85 }
    }
    Column {
      anchors.right: parent.right
      visible: cal.hasW
      Text { anchors.right: parent.right; text: cal.hasW ? cal.wx(cal.w.code)[1] : ""; font.family: cal.icons; font.pixelSize: 26; color: cal.text2 }
      Text { anchors.right: parent.right; text: cal.hasW ? Math.round(cal.w.temp) + cal.unit : ""; font.family: cal.font; font.pixelSize: 20; font.weight: 800; color: cal.fg }
      Text { anchors.right: parent.right; text: cal.hasW ? cal.wx(cal.w.code)[2] : ""; font.family: cal.font; font.pixelSize: 8; color: cal.text2 }
    }
    Column {
      anchors.bottom: parent.bottom
      width: parent.width
      spacing: 4
      Text { text: Qt.formatDate(cal.now, "MMMM yyyy").toUpperCase(); font.family: cal.font; font.pixelSize: 8; font.weight: 700; font.letterSpacing: 1; color: cal.text2 }
      Month { cw: (parent.width - 12) / 7; ch: 14; px: 8 }
    }
  }
}

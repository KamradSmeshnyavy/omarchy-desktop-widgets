import QtQuick

// Календарь месяца на столе (по мотивам виджета yami, Trendorin/yami, MIT; код свой): «Ноябрь 2026», дни недели с
// понедельника, сетка 7 × 6, сегодня — ячейка с рамкой и заливкой акцентом, дни соседних месяцев не показываются.
// Колесо — соседний месяц, клик по заголовку — вернуться к текущему. Подложку рисует WidgetCard по стилю.
Item {
  id: cal

  required property var host
  readonly property color fg: host.foreground
  readonly property color acc: host.accent
  readonly property string px: Qt.fontFamilies().indexOf("Tiny5") !== -1 && String(host.value("clockStyle")) === "yami" ? "Tiny5" : host.fontFamily

  // язык — как у остальных виджетов (host.locale)
  readonly property var loc: typeof cal.host.locale === "string" ? Qt.locale(cal.host.locale) : (cal.host.locale || Qt.locale())
  property date now: new Date()
  Timer { interval: 60000; repeat: true; running: cal.visible; onTriggered: cal.now = new Date() }
  property int shift: 0                 // месяцев от текущего
  readonly property date month: new Date(now.getFullYear(), now.getMonth() + shift, 1)
  readonly property int lead: (month.getDay() + 6) % 7          // пустых клеток до 1-го (неделя с понедельника)
  readonly property int days: new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate()

  readonly property int cell: 36
  implicitWidth: 7 * cell + 8
  implicitHeight: 34 + 22 + 6 * 27 + 4
  width: implicitWidth
  height: implicitHeight

  Text {
    x: 6; y: 6
    text: { var m = cal.loc.standaloneMonthName(cal.month.getMonth()); return m.charAt(0).toUpperCase() + m.slice(1) + " " + cal.month.getFullYear() }
    color: cal.fg; opacity: 0.75
    font.family: cal.px; font.pixelSize: 14
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: cal.shift = 0 }
  }
  Row {
    x: 4; y: 34
    Repeater {
      model: 7
      Text {
        required property int index
        width: cal.cell
        horizontalAlignment: Text.AlignHCenter
        text: { var d = cal.loc.dayName((index + 1) % 7, Locale.ShortFormat).slice(0, 2); return d.charAt(0).toUpperCase() + d.slice(1) }
        color: cal.fg; opacity: 0.35
        font.family: cal.px; font.pixelSize: 12
      }
    }
  }
  Grid {
    x: 4; y: 56
    columns: 7
    Repeater {
      model: 42
      Item {
        required property int index
        readonly property int d: index - cal.lead + 1
        readonly property bool real: d >= 1 && d <= cal.days
        readonly property bool today: real && cal.shift === 0 && d === cal.now.getDate()
        width: cal.cell; height: 27
        Rectangle {
          visible: parent.today
          anchors.centerIn: parent
          width: 26; height: 22
          color: Qt.rgba(cal.acc.r, cal.acc.g, cal.acc.b, 0.35)
          border.width: 1; border.color: cal.acc
        }
        Text {
          anchors.centerIn: parent
          visible: parent.real
          text: parent.d
          color: parent.today ? "white" : cal.fg
          opacity: parent.today ? 1 : (parent.index % 7 >= 5 ? 0.45 : 0.7)
          font.family: cal.px; font.pixelSize: 13
        }
      }
    }
  }
  WheelHandler { onWheel: function(e) { cal.shift += e.angleDelta.y > 0 ? -1 : 1 } }
}

import QtQuick
import QtQuick.Shapes

// Монитор yami (sysinfoStyle "yami", по мотивам Trendorin/yami, MIT; код свой): три карточки одна под другой —
// cpu, memory, temperature. В шапке значок и подпись, справа значение (у памяти — ещё «занято / всего ГБ»), ниже —
// график за последние минуты: линия в пиксель и под ней тусклая заливка. Карточки — плоские панели с рамкой в пиксель
// и жёсткой тенью (как материал pixel), рисуются здесь же, поэтому WidgetCard у этого стиля не нужен.
Item {
  id: ys
  required property var host
  readonly property color fg: host.foreground
  readonly property string px: Qt.fontFamilies().indexOf("Tiny5") !== -1 ? "Tiny5" : host.fontFamily
  readonly property int cw: 300
  readonly property int ch: 108
  readonly property int gap: 38

  // температура — своя история (у Widgets её нет)
  property var tempHistory: []
  Timer {
    interval: 2000; repeat: true; running: ys.visible; triggeredOnStart: true
    onTriggered: ys.tempHistory = ys.tempHistory.concat([Math.min(1, ys.host.temp / 100)]).slice(-60)
  }

  implicitWidth: cw + 3
  implicitHeight: 3 * ch + 2 * gap + 3

  readonly property var panels: [
    { icon: "󰍛", label: "cpu", value: Math.round(ys.host.cpu * 100) + "%", series: ys.host.cpuHistory },
    { icon: "󰘚", label: "memory", series: ys.host.memHistory,
      value: Math.round(ys.host.mem * 100) + "%" + (ys.host.memTotalGb > 0 ? "  " + ys.host.memUsedGb.toFixed(1) + "/" + Math.round(ys.host.memTotalGb) + " GB" : "") },
    { icon: "󰔏", label: "temperature", value: Math.round(ys.host.temp) + "°C", series: ys.tempHistory }
  ]

  Column {
    spacing: ys.gap
    Repeater {
      model: ys.panels
      Item {
        id: p
        required property var modelData
        width: ys.cw; height: ys.ch
        Rectangle { x: 3; y: 3; width: parent.width; height: parent.height; color: Qt.rgba(0, 0, 0, 0.55) }
        Rectangle {
          anchors.fill: parent
          color: Qt.rgba(ys.host.background.r * 0.85, ys.host.background.g * 0.85, ys.host.background.b * 0.85, 0.92)
          border.width: 1
          border.color: Qt.rgba(ys.fg.r, ys.fg.g, ys.fg.b, 0.16)
        }
        Text { x: 10; y: 8; text: p.modelData.icon; color: ys.fg; opacity: 0.5; font.family: ys.host.iconFamily; font.pixelSize: 13 }
        Text { x: 28; y: 8; text: p.modelData.label; color: ys.fg; opacity: 0.55; font.family: ys.px; font.pixelSize: 14 }
        Text { anchors.right: parent.right; anchors.rightMargin: 10; y: 8; text: p.modelData.value; color: ys.fg; opacity: 0.7; font.family: ys.px; font.pixelSize: 14 }
        // график: пиксельная линия и тусклая заливка до дна
        Shape {
          id: gr
          x: 8; y: 40; width: p.width - 16; height: p.height - 50
          readonly property var pts: {
            var s = p.modelData.series || [], n = Math.max(2, s.length), out = []
            for (var i = 0; i < s.length; i++)
              out.push(Qt.point(Math.round(gr.width * i / (n - 1)), Math.round(gr.height - 1 - (gr.height - 2) * Math.max(0, Math.min(1, s[i])))))
            return out
          }
          readonly property var area: pts.length ? [Qt.point(0, gr.height)].concat(pts).concat([Qt.point(pts[pts.length - 1].x, gr.height)]) : []
          ShapePath {
            strokeWidth: -1
            fillColor: Qt.rgba(ys.fg.r, ys.fg.g, ys.fg.b, 0.07)
            PathPolyline { path: gr.area }
          }
          ShapePath {
            strokeColor: Qt.rgba(ys.fg.r, ys.fg.g, ys.fg.b, 0.5); strokeWidth: 1; fillColor: "transparent"
            PathPolyline { path: gr.pts }
          }
        }
        // риски по дну
        Repeater {
          model: Math.floor((p.width - 16) / 6)
          Rectangle { required property int index; x: 8 + index * 6; y: p.height - 9; width: 2; height: 1; color: ys.fg; opacity: 0.18 }
        }
      }
    }
  }
}

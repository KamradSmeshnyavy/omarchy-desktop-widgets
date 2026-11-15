import QtQuick
import QtQuick.Shapes

// Монитор yami (sysinfoStyle "yami", по мотивам Trendorin/yami, MIT; код свой): три карточки одна под другой —
// cpu, memory, temperature. В шапке значок и подпись, справа значение (у памяти — ещё «занято / всего ГБ»), ниже —
// график за последние минуты — столбики акцентом. Карточки — плоские панели с рамкой в пиксель
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
        Text { x: 10; y: 8; text: p.modelData.icon; color: ys.host.accent; font.family: ys.host.iconFamily; font.pixelSize: 13 }
        Text { x: 28; y: 8; text: p.modelData.label; color: ys.fg; opacity: 0.55; font.family: ys.px; font.pixelSize: 14 }
        Text { anchors.right: parent.right; anchors.rightMargin: 10; y: 8; text: p.modelData.value; color: ys.fg; opacity: 0.7; font.family: ys.px; font.pixelSize: 14 }
        // график: столбики акцентом по одному на отсчёт, от дна вверх
        Item {
          id: gr
          x: 8; y: 40; width: p.width - 16; height: p.height - 50
          readonly property var vals: p.modelData.series || []
          readonly property int n: Math.max(1, Math.floor(width / 4))
          Repeater {
            model: Math.min(gr.vals.length, gr.n)
            Rectangle {
              required property int index
              readonly property real v: gr.vals[gr.vals.length - Math.min(gr.vals.length, gr.n) + index] || 0
              x: gr.width - (Math.min(gr.vals.length, gr.n) - index) * 4
              width: 3
              height: Math.max(1, Math.round((gr.height - 2) * Math.max(0, Math.min(1, v))))
              y: gr.height - height
              color: ys.host.accent
              opacity: 0.85
            }
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

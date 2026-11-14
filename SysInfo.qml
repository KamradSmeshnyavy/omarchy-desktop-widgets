import QtQuick
import QtQuick.Shapes
import "dotmatrix" as DotMatrix

// Кольца системы: CPU, RAM, температура, батарея (если есть). Данные — Widgets.qml (/proc, /sys).
// sysinfoStyle "vitreus" — карточка-монитор Vitreus (VitSys.qml) вместо ряда колец.
Item {
  id: root
  required property var host
  readonly property bool vit: String(host.value("sysinfoStyle")) === "vitreus"
  implicitWidth: vit ? vitCard.implicitWidth : sys.implicitWidth
  implicitHeight: vit ? vitCard.implicitHeight : sys.implicitHeight

  VitSys { id: vitCard; host: root.host; visible: root.vit }

Row {
  id: sys
  visible: !root.vit

  readonly property var host: root.host

  spacing: 18

  Repeater {
    model: [
      { label: "CPU", value: sys.host.cpu, text: Math.round(sys.host.cpu * 100) + (sys.host.dotmatrixWidgets ? "" : "%") },
      { label: "RAM", value: sys.host.mem, text: Math.round(sys.host.mem * 100) + (sys.host.dotmatrixWidgets ? "" : "%") },
      { label: sys.host.dotmatrixWidgets ? "°C" : "TEMP", value: Math.min(1, sys.host.temp / 100), text: Math.round(sys.host.temp) + (sys.host.dotmatrixWidgets ? "" : "°"), hot: sys.host.temp >= 85 },
      { label: sys.host.batteryStatus === "Charging" && !sys.host.dotmatrixWidgets ? "BAT 󱐋" : "BAT", value: sys.host.battery / 100,
        text: sys.host.battery + (sys.host.dotmatrixWidgets ? "" : "%"), hot: sys.host.battery >= 0 && sys.host.battery <= 15, hidden: sys.host.battery < 0 }
    ]

    delegate: Item {
      id: slot
      required property var modelData
      visible: !modelData.hidden
      implicitWidth: sys.host.dotmatrixWidgets ? 84 : stdRing.implicitWidth
      implicitHeight: sys.host.dotmatrixWidgets ? 84 : stdRing.implicitHeight

      DotMatrix.Dial {
        visible: sys.host.dotmatrixWidgets
        width: 84
        height: 84
        value: slot.modelData.value
        text: slot.modelData.text
        label: slot.modelData.label
        alert: slot.modelData.hot === true
      }

      Column {
        id: stdRing
        visible: !sys.host.dotmatrixWidgets
        spacing: 6

        readonly property int size: 72
        readonly property color tint: slot.modelData.hot ? sys.host.resolve("red", "#e05561") : sys.host.accent

        Item {
          width: stdRing.size
          height: stdRing.size

          Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
              fillColor: "transparent"
              strokeColor: Qt.rgba(sys.host.foreground.r, sys.host.foreground.g, sys.host.foreground.b, 0.12)
              strokeWidth: 6
              capStyle: ShapePath.RoundCap
              PathAngleArc { centerX: stdRing.size / 2; centerY: stdRing.size / 2; radiusX: stdRing.size / 2 - 4; radiusY: radiusX; startAngle: 135; sweepAngle: 270 }
            }
            ShapePath {
              fillColor: "transparent"
              strokeColor: stdRing.tint
              strokeWidth: 6
              capStyle: ShapePath.RoundCap
              PathAngleArc {
                centerX: stdRing.size / 2; centerY: stdRing.size / 2; radiusX: stdRing.size / 2 - 4; radiusY: radiusX
                startAngle: 135
                sweepAngle: Math.max(0.5, 270 * Math.max(0, Math.min(1, slot.modelData.value)))
                Behavior on sweepAngle { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
              }
            }
          }
          Text {
            anchors.centerIn: parent
            text: slot.modelData.text
            font.family: sys.host.fontFamily
            font.pixelSize: 15
            font.weight: Font.Bold
            color: sys.host.foreground
          }
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: slot.modelData.label
          font.family: sys.host.fontFamily
          font.pixelSize: 11
          font.letterSpacing: 2
          color: sys.host.foreground
          opacity: 0.65
        }
      }
    }
  }
}
}

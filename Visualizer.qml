import QtQuick
import QtQuick.Shapes
import "dotmatrix" as DotMatrix

// Визуализатор cava у нижнего края экрана. Стили (visualizerStyle): bars — столбики
// снизу; mirror — столбики, отражённые от середины; wave — сглаженная линия с заливкой.
Item {
  id: viz

  required property var host
  readonly property var levels: host.levels
  readonly property string style: String(host.value("visualizerStyle"))
  readonly property real alpha: Math.max(0.05, Math.min(1, host.num("visualizerAlpha")))
  readonly property color tint: Qt.rgba(host.accent.r, host.accent.g, host.accent.b, alpha)

  opacity: host.playing ? 1 : 0.5
  Behavior on opacity { NumberAnimation { duration: 400 } }

  readonly property bool dotmatrix: host.dotmatrixWidgets

  Row {
    id: dotRow
    visible: viz.dotmatrix
    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 8 }
    readonly property real slot: width / Math.max(1, viz.levels.length)
    readonly property int dotRows: Math.max(4, Math.min(18, Math.floor(viz.height / 9)))

    Repeater {
      model: viz.dotmatrix ? viz.levels.length : 0
      delegate: Column {
        id: dotCol
        required property int index
        readonly property int lit: Math.round((viz.levels[index] || 0) * dotRow.dotRows)
        width: dotRow.slot
        spacing: 3

        Repeater {
          model: dotRow.dotRows
          delegate: Rectangle {
            required property int index
            anchors.horizontalCenter: parent.horizontalCenter
            width: 5
            height: 5
            radius: 2.5
            color: (dotRow.dotRows - index) <= dotCol.lit
              ? DotMatrix.Palette.alpha(DotMatrix.Palette.lit, viz.alpha)
              : DotMatrix.Palette.alpha(DotMatrix.Palette.unlit, DotMatrix.Palette.unlit.a * viz.alpha * (DotMatrix.Palette.mono ? 0.45 : 1))
          }
        }
      }
    }
  }

  Row {
    visible: !viz.dotmatrix && viz.style !== "wave"
    anchors.fill: parent
    readonly property real slot: width / Math.max(1, viz.levels.length)

    Repeater {
      model: viz.levels.length
      delegate: Item {
        required property int index
        width: parent.slot
        height: viz.height
        readonly property real level: viz.levels[index] || 0

        Rectangle {
          width: Math.max(2, parent.width * 0.62)
          anchors.horizontalCenter: parent.horizontalCenter
          height: Math.max(2, parent.level * (viz.style === "mirror" ? viz.height / 2 : viz.height))
          y: viz.style === "mirror" ? (viz.height - height) / 2 : viz.height - height
          radius: width / 2
          gradient: Gradient {
            GradientStop { position: 0; color: viz.tint }
            GradientStop { position: 1; color: Qt.rgba(viz.tint.r, viz.tint.g, viz.tint.b, viz.alpha * 0.25) }
          }
          Behavior on height { NumberAnimation { duration: 60 } }
        }
      }
    }
  }

  Shape {
    visible: !viz.dotmatrix && viz.style === "wave"
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeColor: viz.tint
      strokeWidth: 2
      fillGradient: LinearGradient {
        x1: 0; y1: 0; x2: 0; y2: viz.height
        GradientStop { position: 0; color: Qt.rgba(viz.tint.r, viz.tint.g, viz.tint.b, viz.alpha * 0.6) }
        GradientStop { position: 1; color: "transparent" }
      }
      startX: 0
      startY: viz.height
      PathPolyline {
        path: {
          var n = viz.levels.length
          var pts = [Qt.point(0, viz.height)]
          for (var i = 0; i < n; i++)
            pts.push(Qt.point(n > 1 ? i * viz.width / (n - 1) : 0, viz.height - (viz.levels[i] || 0) * viz.height * 0.9))
          pts.push(Qt.point(viz.width, viz.height))
          return pts
        }
      }
    }
  }
}

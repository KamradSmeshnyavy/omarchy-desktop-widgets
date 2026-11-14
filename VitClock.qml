import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// Часы стола Vitreus (по мотивам desktopclock/clockface.plm, MIT; код свой): цифры — стеклянные трубки одним штрихом
// (центральная линия в боксе 46 × 88, толщина 13·k), светлый ободок и полупрозрачная середина, мягкая тень. Раскладки
// (clockVitreusLayout): rule — часы над минутами с чертой между ними; pipe — 12 | 34; digital — 12:34. k — масштаб
// (цифра 88·k высотой), tint — цвет «стекла».
Item {
  id: face

  property string hours: "12"
  property string minutes: "34"
  property string layout: "rule"
  property real k: 1.4
  property color tint: "#ffffff"
  property color ink: "#000000"

  readonly property real sw: 13 * k
  readonly property real dw: 46 * k
  readonly property real dh: 88 * k
  readonly property real step: 76 * k
  readonly property bool rule: layout === "rule"

  // центральные линии цифр 0–9 в боксе 46 × 88
  readonly property var paths: [
    "M23 2 C6 2 2 20 2 44 C2 68 6 86 23 86 C40 86 44 68 44 44 C44 20 40 2 23 2 Z",
    "M10 16 L26 2 L26 86",
    "M3 20 C3 8 12 2 23 2 C35 2 44 9 44 22 C44 36 33 44 20 56 L3 86 L44 86",
    "M3 10 C8 4 15 2 23 2 C35 2 43 9 43 22 C43 34 34 42 20 42 C35 42 45 50 45 63 C45 77 35 86 22 86 C13 86 6 83 2 77",
    "M34 86 L34 2 L2 62 L46 62",
    "M42 2 L8 2 L5 40 C10 36 16 34 24 34 C36 34 45 43 45 59 C45 76 35 86 22 86 C13 86 6 82 2 76",
    "M40 6 C35 3 30 2 25 2 C10 2 3 18 3 46 C3 72 10 86 24 86 C37 86 45 76 45 62 C45 48 37 40 24 40 C14 40 6 46 3 54",
    "M2 2 L44 2 L16 86",
    "M23 42 C11 42 5 35 5 23 C5 10 13 2 23 2 C33 2 41 10 41 23 C41 35 35 42 23 42 C9 42 3 51 3 64 C3 78 12 86 23 86 C34 86 43 78 43 64 C43 51 37 42 23 42 Z",
    "M43 34 C40 42 32 48 22 48 C9 48 2 39 2 25 C2 11 10 2 23 2 C37 2 43 14 43 40 C43 70 36 86 21 86 C15 86 10 85 6 82"
  ]
  function scaled(path) {
    return path.replace(/-?\d+(\.\d+)?/g, function(n) { return String(Number(n) * face.k) })
  }

  // места цифр: [x, y, цифра]
  readonly property var places: {
    var h = hours, m = minutes, out = []
    if (rule) {
      out.push([0, 0, h[0]], [step, 0, h[1]], [0, dh + 46 * k, m[0]], [step, dh + 46 * k, m[1]])
    } else if (layout === "pipe") {
      out.push([0, 0, h[0]], [step, 0, h[1]], [2 * step + 30 * k, 0, m[0]], [3 * step + 30 * k, 0, m[1]])
    } else {
      out.push([0, 0, h[0]], [step, 0, h[1]], [2 * step + 30 * k, 0, m[0]], [3 * step + 30 * k, 0, m[1]])
    }
    return out
  }
  implicitWidth: rule ? step + dw + sw : 3 * step + 30 * k + dw + sw
  implicitHeight: rule ? 2 * dh + 46 * k + sw : dh + sw

  Item {
    id: body
    anchors.fill: parent
    layer.enabled: true
    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowOpacity: 0.28; shadowBlur: 0.7; shadowVerticalOffset: 6 * face.k }

    Repeater {
      model: face.places
      Item {
        id: cell
        required property var modelData
        x: modelData[0] + face.sw / 2
        y: modelData[1] + face.sw / 2
        width: face.dw; height: face.dh
        readonly property string p: face.scaled(face.paths[Number(modelData[2]) || 0])
        // трубка: светлый ободок, внутри — стекло
        Shape {
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          ShapePath { strokeColor: Qt.rgba(1, 1, 1, 0.75); strokeWidth: face.sw; fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin; PathSvg { path: cell.p } }
          ShapePath { strokeColor: Qt.rgba(face.tint.r, face.tint.g, face.tint.b, 0.55); strokeWidth: Math.max(1, face.sw - 3.2 * face.k); fillColor: "transparent"; capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin; PathSvg { path: cell.p } }
        }
      }
    }
    // черта между часами и минутами (rule) или вертикальная (pipe), двоеточие (digital)
    Rectangle {
      visible: face.rule || face.layout === "pipe"
      x: face.rule ? (face.width - 122 * face.k) / 2 : 2 * face.step + 15 * face.k - 3 * face.k
      y: face.rule ? face.dh + 23 * face.k + face.sw / 2 - 3 * face.k : face.sw / 2 + face.dh / 2 - 59 * face.k
      width: face.rule ? 122 * face.k : 6 * face.k
      height: face.rule ? 6 * face.k : 118 * face.k
      radius: Math.min(width, height) / 2
      color: Qt.rgba(face.tint.r, face.tint.g, face.tint.b, 0.55)
      border.width: 1.4
      border.color: Qt.rgba(1, 1, 1, 0.75)
    }
    Repeater {
      model: face.layout === "digital" ? 2 : 0
      Rectangle {
        required property int index
        x: 2 * face.step + 15 * face.k - 7 * face.k + face.sw / 2
        y: face.sw / 2 + face.dh / 2 + (index ? 16 : -14) * face.k - 7 * face.k
        width: 14 * face.k; height: width; radius: width / 2
        color: Qt.rgba(face.tint.r, face.tint.g, face.tint.b, 0.55)
        border.width: 1.4; border.color: Qt.rgba(1, 1, 1, 0.75)
      }
    }
  }
}

import QtQuick
import QtQuick.Shapes

// Системный монитор Vitreus (по мотивам desktopsysmon.plm, MIT; код свой): карточка 364 × 240 — сверху хост и аптайм,
// три кольца r36 на 270° (CPU, память, видеокарта — если ядро отдаёт gpu_busy_percent; иначе температура), под ними
// подписи, внизу — сеть: 120 столбиков зеркально от базовой линии (вверх — приём, вниз — отдача), график плавно едет
// влево. Подложку рисует WidgetCard (стекло или пластик основы темы) — здесь только содержимое.
Item {
  id: v

  required property var host

  implicitWidth: 364
  implicitHeight: 240

  readonly property color tx: host.foreground
  readonly property color mint: host.accent
  readonly property color alert: host.resolve("red", "#e05561")
  readonly property string font: host.fontFamily
  function mixc(a, b, k) { return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, 1) }
  function pct(x) { return Math.round(Math.max(0, Math.min(1, x)) * 100) + "%" }
  function rate(b) {
    if (b >= 1048576) return (b / 1048576).toFixed(b >= 10485760 ? 0 : 1) + " MB/s"
    if (b >= 1024) return Math.round(b / 1024) + " KB/s"
    return Math.round(b) + " B/s"
  }
  function upText(s) {
    var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
    return "up " + (d > 0 ? d + "d " : "") + (d > 0 || h > 0 ? h + "h " : "") + m + "m"
  }

  readonly property bool gpuOn: host.gpu >= 0
  readonly property var gauges: [
    { x: 70, value: host.cpu, label: "CPU", warn: 0.75, meta: Math.round(host.temp) + "°C" },
    { x: 182, value: host.mem, label: "MEMORY", warn: 0.85, meta: host.memUsedGb.toFixed(1) + " / " + host.memTotalGb.toFixed(0) + " GB" },
    v.gpuOn ? { x: 294, value: host.gpu / 100, label: "GRAPHICS", warn: 0.85, meta: host.gpuName }
            : { x: 294, value: Math.min(1, host.temp / 100), label: "TEMP", warn: 0.8, meta: host.battery >= 0 ? "BAT " + host.battery + "%" : "" }
  ]
  readonly property real ry: 92

  // ── шапка ──
  Text {
    x: 18; y: 18; width: 190
    text: v.host.hostName
    elide: Text.ElideRight
    font.family: v.font; font.pixelSize: 17; font.weight: Font.Bold
    color: v.tx
  }
  Text {
    anchors { right: parent.right; rightMargin: 18 }
    y: 20; width: 120
    horizontalAlignment: Text.AlignRight
    text: v.upText(v.host.uptime)
    font.family: v.font; font.pixelSize: 13; font.weight: Font.DemiBold
    color: v.tx; opacity: 0.8
  }

  // ── кольца ──
  Repeater {
    model: v.gauges
    Item {
      id: g
      required property var modelData
      readonly property real val: Math.max(0.004, Math.min(1, modelData.value))
      readonly property color col: v.mixc(v.mint, v.alert, Math.max(0, Math.min(1, (val - modelData.warn) / (1 - modelData.warn))))
      x: modelData.x - 56; y: v.ry - 44
      width: 112; height: 112
      Shape {
        x: 12; y: 0; width: 88; height: 88
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          fillColor: "transparent"; strokeWidth: 8; capStyle: ShapePath.RoundCap
          strokeColor: Qt.rgba(v.tx.r, v.tx.g, v.tx.b, 0.13)
          PathAngleArc { centerX: 44; centerY: 44; radiusX: 36; radiusY: 36; startAngle: 135; sweepAngle: 270 }
        }
        ShapePath {
          fillColor: "transparent"; strokeWidth: 8; capStyle: ShapePath.RoundCap
          strokeColor: g.col
          PathAngleArc {
            centerX: 44; centerY: 44; radiusX: 36; radiusY: 36; startAngle: 135
            sweepAngle: 270 * g.val
            Behavior on sweepAngle { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
          }
        }
      }
      Text {
        x: 12; width: 88; y: 44 - 4 - height / 2
        horizontalAlignment: Text.AlignHCenter
        text: v.pct(g.modelData.value)
        font.family: v.font; font.pixelSize: 20; font.weight: Font.Bold
        color: v.tx
      }
      Text {
        x: 12; width: 88; y: 44 + 13 - height / 2
        horizontalAlignment: Text.AlignHCenter
        text: g.modelData.label
        font.family: v.font; font.pixelSize: 10; font.weight: Font.Bold
        color: v.tx; opacity: 0.75
      }
      Text {
        width: 112; y: 92 - height / 2
        horizontalAlignment: Text.AlignHCenter
        text: g.modelData.meta
        elide: Text.ElideRight
        font.family: v.font; font.pixelSize: 12; font.weight: Font.DemiBold
        color: v.tx; opacity: 0.85
      }
    }
  }

  // ── сеть ──
  Text {
    x: 18; y: 172 - height / 2
    text: "NETWORK"
    font.family: v.font; font.pixelSize: 11; font.weight: Font.Bold
    color: v.tx; opacity: 0.75
  }
  Text {
    x: 110; y: 172 - height / 2; width: 112
    text: "↓ " + v.rate(v.host.rxRate)
    font.family: v.font; font.pixelSize: 13; font.weight: Font.Bold
    color: v.tx
  }
  Text {
    anchors { right: parent.right; rightMargin: 18 }
    y: 172 - height / 2; width: 112
    horizontalAlignment: Text.AlignRight
    text: "↑ " + v.rate(v.host.txRate)
    font.family: v.font; font.pixelSize: 13; font.weight: Font.Bold
    color: v.mixc(v.mint, v.tx, 0.4)
  }

  // график: 120 столбиков по 2.6 px с шагом 2.835 (как у Vitreus), высота — доля от максимума за окно
  Item {
    id: graph
    x: 10; y: 184; width: 344; height: 54
    clip: true
    readonly property var rx: v.host.rxLong
    readonly property var txh: v.host.txLong
    readonly property real peak: {
      var m = 65536
      for (var i = 0; i < rx.length; i++) m = Math.max(m, rx[i], txh[i] || 0)
      return m
    }
    readonly property real base: 30
    readonly property real step: 2.835
    // новая точка приходит раз в 2 с — весь график едет на шаг за это время, без рывков
    property real glide: 0
    Connections {
      target: v.host
      function onRxLongChanged() { slide.restart() }
    }
    NumberAnimation { id: slide; target: graph; property: "glide"; from: 1; to: 0; duration: 2000 }

    Rectangle { x: 2; y: graph.base - 1.2; width: 340; height: 2.4; radius: 1.2; color: Qt.rgba(v.tx.r, v.tx.g, v.tx.b, 0.13) }
    Item {
      x: graph.glide * graph.step
      width: parent.width; height: parent.height
      Repeater {
        model: graph.rx.length
        Item {
          required property int index
          readonly property int k: index + 120 - graph.rx.length
          readonly property real dh: Math.max(1.2, Math.min(1, graph.rx[index] / graph.peak) * 26)
          readonly property real uh: Math.max(1.2, Math.min(1, (graph.txh[index] || 0) / graph.peak) * 22)
          Rectangle {
            x: 1.4 + (parent.k + 0.5) * graph.step - 1.3; y: graph.base - 2 - parent.dh
            width: 2.6; height: parent.dh; radius: 1.2
            color: v.mint; opacity: 0.25 + 0.7 * parent.k / 120
          }
          Rectangle {
            x: 1.4 + (parent.k + 0.5) * graph.step - 1.3; y: graph.base + 2
            width: 2.6; height: parent.uh; radius: 1.2
            color: v.mixc(v.mint, v.tx, 0.4); opacity: 0.2 + 0.55 * parent.k / 120
          }
        }
      }
    }
  }
}

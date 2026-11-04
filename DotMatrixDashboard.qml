import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "dotmatrix" as DotMatrix

// DOT-MATRIX hardware dashboard drawer. Attached to a solid bar (BarStyle, host.panelStyle) it grows
// out of the bar with concave fillets and an open-top hairline; otherwise it hangs below the
// bar as a separate card with a closed contour. Fill = bar colour, ink = DOT-MATRIX palette.
PanelWindow {
  id: dash

  required property var host

  readonly property bool active: host.dotmatrixDash && host.dashboardOpen
  readonly property bool attached: host.panelStyle.attached
  readonly property int flare: attached ? host.panelStyle.flare : 0
  readonly property int cornerRadius: 18
  readonly property int seamOverlap: attached ? 2 : 0
  readonly property int bodyWidth: Math.min(960, (screen ? screen.width : 1280) - 140)
  readonly property int bodyHeight: 296
  readonly property int duration: Math.max(120, host.num("dashDuration"))

  property real progress: active ? 1 : 0
  Behavior on progress { NumberAnimation { duration: dash.duration; easing.type: Easing.OutCubic } }

  readonly property real h: Math.round(bodyHeight * progress)
  readonly property real contentReveal: Math.max(0, (progress - 0.45) / 0.55)

  // Resample host.levels (arbitrary bar count, 0..1) into 24 discrete 0..6 LED columns.
  readonly property var ledSpectrum: {
    var src = host.levels || []
    var cols = 24
    var rows = 6
    var out = []
    if (src.length === 0) {
      for (var z = 0; z < cols; z++) out.push(0)
      return out
    }
    for (var i = 0; i < cols; i++) {
      var idx = Math.min(src.length - 1, Math.floor(i * src.length / cols))
      var v = Math.max(0, Math.min(1, Number(src[idx] || 0)))
      out.push(Math.round(v * rows))
    }
    return out
  }

  function formatClock(sec) {
    var s = Math.max(0, Math.floor(Number(sec || 0)))
    var m = Math.floor(s / 60)
    var r = s % 60
    return m + ":" + (r < 10 ? "0" + r : String(r))
  }

  function formatRate(bytes) {
    var b = Math.max(0, Number(bytes || 0))
    if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB/S"
    if (b >= 1024) return Math.round(b / 1024) + " KB/S"
    return Math.round(b) + " B/S"
  }

  visible: host.dotmatrixDash && progress > 0.001
  screen: host.focusedScreen
  anchors.top: true
  margins.top: attached ? -seamOverlap : 10
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: 0
  implicitWidth: bodyWidth + 2 * flare + 4
  implicitHeight: bodyHeight + seamOverlap + 2
  color: "transparent"
  surfaceFormat.opaque: false
  WlrLayershell.namespace: "omarchy-dotmatrix-dashboard"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  mask: Region { item: hit }

  HyprlandFocusGrab {
    active: dash.active
    windows: [dash]
    onCleared: dash.host.dashboardOpen = false
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Item {
    id: hit
    x: Math.round((dash.width - dash.bodyWidth) / 2)
    y: 0
    width: dash.bodyWidth
    height: dash.seamOverlap + dash.h
  }

  Shape {
    id: dashShape
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    readonly property real baseY: dash.attached ? dash.seamOverlap - 0.5 : 0.5
    readonly property real bottomY: dash.seamOverlap + dash.h
    readonly property real fy: Math.min(dash.flare, dash.h)
    readonly property real br: Math.max(0, Math.min(dash.cornerRadius, (dash.h - fy) / 2))
    readonly property real leftX: hit.x
    readonly property real rightX: hit.x + hit.width

    // Body in the bar colour, extending up to y=0 so the frame's top hairline is erased across the opening.
    ShapePath {
      fillColor: dash.host.panelStyle.color
      strokeWidth: -1
      startX: dashShape.leftX - dash.flare
      startY: 0

      PathLine { x: dashShape.rightX + dash.flare; y: 0 }
      PathLine { x: dashShape.rightX + dash.flare; y: dashShape.baseY }
      PathArc {
        x: dashShape.rightX
        y: dashShape.baseY + dashShape.fy
        radiusX: Math.max(0.01, dash.flare)
        radiusY: Math.max(0.01, dashShape.fy)
        direction: PathArc.Counterclockwise
      }
      PathLine { x: dashShape.rightX; y: dashShape.bottomY - dashShape.br }
      PathArc {
        x: dashShape.rightX - dashShape.br
        y: dashShape.bottomY
        radiusX: Math.max(0.01, dashShape.br)
        radiusY: Math.max(0.01, dashShape.br)
      }
      PathLine { x: dashShape.leftX + dashShape.br; y: dashShape.bottomY }
      PathArc {
        x: dashShape.leftX
        y: dashShape.bottomY - dashShape.br
        radiusX: Math.max(0.01, dashShape.br)
        radiusY: Math.max(0.01, dashShape.br)
      }
      PathLine { x: dashShape.leftX; y: dashShape.baseY + dashShape.fy }
      PathArc {
        x: dashShape.leftX - dash.flare
        y: dashShape.baseY
        radiusX: Math.max(0.01, dash.flare)
        radiusY: Math.max(0.01, dashShape.fy)
        direction: PathArc.Counterclockwise
      }
      PathLine { x: dashShape.leftX - dash.flare; y: 0 }
    }

    // 1px hairline: open-top when attached (joins ScreenBorder's inner contour at baseY),
    // closed across the top for a floating card.
    ShapePath {
      fillColor: "transparent"
      strokeColor: dash.host.panelStyle.borderWidth > 0 ? dash.host.panelStyle.borderColor : DotMatrix.Palette.line
      strokeWidth: dash.h > 1 ? 1 : -1
      startX: dashShape.rightX + dash.flare
      startY: dashShape.baseY

      PathArc {
        x: dashShape.rightX
        y: dashShape.baseY + dashShape.fy
        radiusX: Math.max(0.01, dash.flare)
        radiusY: Math.max(0.01, dashShape.fy)
        direction: PathArc.Counterclockwise
      }
      PathLine { x: dashShape.rightX; y: dashShape.bottomY - dashShape.br }
      PathArc {
        x: dashShape.rightX - dashShape.br
        y: dashShape.bottomY
        radiusX: Math.max(0.01, dashShape.br)
        radiusY: Math.max(0.01, dashShape.br)
      }
      PathLine { x: dashShape.leftX + dashShape.br; y: dashShape.bottomY }
      PathArc {
        x: dashShape.leftX
        y: dashShape.bottomY - dashShape.br
        radiusX: Math.max(0.01, dashShape.br)
        radiusY: Math.max(0.01, dashShape.br)
      }
      PathLine { x: dashShape.leftX; y: dashShape.baseY + dashShape.fy }
      PathArc {
        x: dashShape.leftX - dash.flare
        y: dashShape.baseY
        radiusX: Math.max(0.01, dash.flare)
        radiusY: Math.max(0.01, dashShape.fy)
        direction: PathArc.Counterclockwise
      }
      PathLine { x: dash.attached ? dashShape.leftX - dash.flare : dashShape.rightX + dash.flare; y: dashShape.baseY }
    }
  }

  Item {
    x: hit.x
    y: dash.seamOverlap
    width: dash.bodyWidth
    height: dash.h
    clip: true
    opacity: dash.contentReveal
    focus: dash.active
    Keys.onEscapePressed: dash.host.dashboardOpen = false

    RowLayout {
      width: dash.bodyWidth - 60
      height: dash.bodyHeight - 44
      x: 30
      y: 20
      spacing: 24

      // 1. Time & status
      ColumnLayout {
        Layout.preferredWidth: 214
        Layout.fillHeight: true
        spacing: 4

        DotMatrix.Label { text: "ex nihilo" }

        DotMatrix.DotText {
          text: Qt.formatDateTime(clock.date, "HH:mm")
          font.pixelSize: 64
        }

        DotMatrix.Txt {
          Layout.fillWidth: true
          text: clock.date.toLocaleDateString(dash.host.locale, "dddd, d MMMM")
          color: DotMatrix.Palette.dim
          font.pixelSize: 15
        }

        Item { Layout.fillHeight: true }

        DotMatrix.Label {
          Layout.fillWidth: true
          text: dash.host.battery >= 0
            ? (dash.host.tr("BATTERY ", "БАТАРЕЯ ") + dash.host.battery + "%"
               + (dash.host.batteryStatus === "Charging" ? (" · " + dash.host.tr("CHARGING", "ЗАРЯДКА")) : ""))
            : (dash.host.netIface !== "" ? ("NET · " + dash.host.netIface) : dash.host.tr("OFFLINE", "ОФЛАЙН"))
        }
      }

      Rectangle {
        Layout.fillHeight: true
        implicitWidth: 1
        color: DotMatrix.Palette.line
      }

      // 2. Dot-matrix media & 24x6 LED spectrum
      ColumnLayout {
        id: musicCol
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 10

        readonly property var player: dash.host.player
        readonly property real trackLen: player && player.lengthSupported && player.length > 0 ? player.length : 0
        readonly property real trackPos: player && player.position > 0 ? player.position : 0
        readonly property real trackRatio: trackLen > 0 ? Math.max(0, Math.min(1, trackPos / trackLen)) : 0

        RowLayout {
          Layout.fillWidth: true
          spacing: 16

          DotMatrix.DotScreen {
            Layout.preferredWidth: 104
            Layout.preferredHeight: 104
            source: musicCol.player ? String(musicCol.player.trackArtUrl || "") : ""
            pitch: 4
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            DotMatrix.Label {
              text: musicCol.player && musicCol.player.identity
                ? String(musicCol.player.identity)
                : dash.host.tr("MEDIA", "МЕДИА")
            }

            DotMatrix.Txt {
              Layout.fillWidth: true
              text: musicCol.player && musicCol.player.trackTitle
                ? String(musicCol.player.trackTitle)
                : dash.host.tr("Nothing playing", "Ничего не играет")
              font.pixelSize: 17
              font.weight: Font.Medium
            }

            DotMatrix.Txt {
              Layout.fillWidth: true
              text: musicCol.player && musicCol.player.trackArtist
                ? String(musicCol.player.trackArtist)
                : ""
              color: DotMatrix.Palette.dim
              visible: text !== ""
            }

            Row {
              Layout.topMargin: 6
              spacing: 8

              DotMatrix.CircleButton {
                glyph: String.fromCodePoint(0xF04AE)
                size: 32
                onClicked: if (dash.host.player && dash.host.player.canGoPrevious) dash.host.player.previous()
              }
              DotMatrix.CircleButton {
                glyph: dash.host.playing ? String.fromCodePoint(0xF03E4) : String.fromCodePoint(0xF040A)
                size: 32
                filled: true
                onClicked: if (dash.host.player && dash.host.player.canTogglePlaying) dash.host.player.togglePlaying()
              }
              DotMatrix.CircleButton {
                glyph: String.fromCodePoint(0xF04AD)
                size: 32
                onClicked: if (dash.host.player && dash.host.player.canGoNext) dash.host.player.next()
              }
            }
          }
        }

        DotMatrix.DotMeter {
          id: mediaMeter
          Layout.fillWidth: true
          Layout.preferredWidth: 0
          count: Math.max(12, Math.floor((width + 3) / 7))
          dot: 4
          gap: 3
          value: musicCol.trackRatio
        }

        RowLayout {
          Layout.fillWidth: true

          DotMatrix.Label { text: dash.formatClock(musicCol.trackPos) }
          Item { Layout.fillWidth: true }
          DotMatrix.Label { text: dash.formatClock(musicCol.trackLen) }
        }

        // 24x6 circular LED matrix visualizer
        Item {
          id: ledViz
          Layout.fillWidth: true
          Layout.fillHeight: true

          Row {
            anchors.centerIn: parent
            spacing: Math.max(2, (ledViz.width - 24 * 5) / 23)

            Repeater {
              model: 24

              Column {
                id: colItem
                required property int index
                readonly property int litRows: dash.ledSpectrum[index] || 0
                spacing: 2

                Repeater {
                  model: 6

                  Rectangle {
                    required property int index
                    width: 5
                    height: 5
                    radius: 2.5
                    color: (6 - index) <= colItem.litRows ? DotMatrix.Palette.lit : DotMatrix.Palette.unlit
                    Behavior on color { ColorAnimation { duration: 70 } }
                  }
                }
              }
            }
          }
        }
      }

      Rectangle {
        Layout.fillHeight: true
        implicitWidth: 1
        color: DotMatrix.Palette.line
      }

      // 3. Instrument cluster (CPU / RAM / °C dials + rx/tx DotScope)
      ColumnLayout {
        Layout.preferredWidth: 264
        Layout.fillHeight: true
        spacing: 10

        Row {
          spacing: 6

          DotMatrix.Dial {
            width: 84; height: 84
            value: dash.host.cpu
            text: String(Math.round(dash.host.cpu * 100))
            label: "cpu"
          }
          DotMatrix.Dial {
            width: 84; height: 84
            value: dash.host.mem
            text: String(Math.round(dash.host.mem * 100))
            label: "ram"
          }
          DotMatrix.Dial {
            width: 84; height: 84
            value: Math.min(1, dash.host.temp / 100)
            text: String(Math.round(dash.host.temp))
            label: "°c"
            alert: dash.host.temp >= 85
          }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
          Layout.fillWidth: true

          DotMatrix.Label { text: "↓ " + dash.formatRate(dash.host.rxRate) }
          Item { Layout.fillWidth: true }
          DotMatrix.Label { text: "↑ " + dash.formatRate(dash.host.txRate); color: DotMatrix.Palette.muted }
        }

        DotMatrix.DotScope {
          Layout.fillWidth: true
          Layout.preferredHeight: 54
          series: dash.host.rxHistory
          secondary: dash.host.txHistory
        }
      }
    }
  }
}

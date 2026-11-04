import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import "nihil" as Nihil

// NIHIL right-edge hardware control drawer: 3x2 circular tiles, 24-segment LED
// sliders, expandable Wi-Fi / Bluetooth / Audio lists, notification history,
// and 2-click red-confirm session actions.
PanelWindow {
  id: panel

  required property var host

  readonly property bool active: host.settingsOpen
  // Grows out of the right edge of a framed bar (ScreenBorder); with any other bar it is a
  // floating card with a closed contour. Fill = bar colour (BarStyle), ink = Nihil palette.
  readonly property bool attached: host.panelStyle.attached && host.panelStyle.shape === "frame"
  readonly property int flare: attached ? host.panelStyle.flare : 0
  readonly property int cornerRadius: 18
  readonly property int seamOverlap: attached ? 2 : 0
  // Плавающая карточка: отступ от края экрана внутри окна — с ним видны правые углы, рамка и тень.
  readonly property int pad: attached ? 0 : 14
  readonly property int bodyWidth: 396
  readonly property int bodyHeight: Math.min((screen ? screen.height : 900) - 112, 820)
  readonly property int duration: 280

  property real progress: active ? 1 : 0
  Behavior on progress { NumberAnimation { duration: panel.duration; easing.type: Easing.OutCubic } }

  readonly property real w: Math.round(bodyWidth * progress)
  readonly property real contentReveal: Math.max(0, (progress - 0.48) / 0.52)

  property string expanded: ""       // "", "wifi", "bt", "audio"
  property string armed: ""          // session action waiting for 2nd click

  // Network state (nmcli)
  property bool wifiEnabled: true
  property string activeSsid: ""
  property string activeEthernet: ""

  // Brightness & night-light state
  property real brightness: 0.7
  property bool brightnessAvailable: false
  property bool nightActive: false

  // DND & notification history
  property bool dndActive: false
  property var notifHistory: []

  // PipeWire audio
  readonly property PwNode sink: Pipewire.defaultAudioSink
  readonly property PwNode source: Pipewire.defaultAudioSource
  readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool muted: !sink || !sink.audio || sink.audio.muted
  readonly property real micVolume: source && source.audio ? source.audio.volume : 0
  readonly property bool micMuted: !source || !source.audio || source.audio.muted

  PwObjectTracker {
    objects: [panel.sink, panel.source].filter(Boolean)
  }

  // Bluetooth
  readonly property var btAdapter: Bluetooth.defaultAdapter
  readonly property bool btEnabled: btAdapter ? btAdapter.enabled : false

  function volGlyph(v, isMuted) {
    if (isMuted || v <= 0) return String.fromCodePoint(0xF075F)
    return v < 0.34 ? String.fromCodePoint(0xF057F) : (v < 0.67 ? String.fromCodePoint(0xF0580) : String.fromCodePoint(0xF057E))
  }

  function parseNmcliFields(line) {
    var out = []
    var cur = ""
    for (var i = 0; i < line.length; i++) {
      var c = line.charAt(i)
      if (c === "\\" && i + 1 < line.length) { cur += line.charAt(++i); continue }
      if (c === ":") { out.push(cur); cur = ""; continue }
      cur += c
    }
    out.push(cur)
    return out
  }

  function toggleSection(name) {
    expanded = expanded === name ? "" : name
  }

  function setWifiRadio(on) {
    wifiEnabled = on
    Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"])
    netRefreshTimer.restart()
  }



  function toggleBluetooth() {
    if (!btAdapter) return
    if (!btEnabled) {
      Quickshell.execDetached(["rfkill", "unblock", "bluetooth"])
      btPowerTimer.restart()
    } else {
      btAdapter.enabled = false
    }
  }


  function setVolume(v) {
    if (!sink || !sink.audio) return
    sink.audio.muted = false
    sink.audio.volume = Math.max(0, Math.min(1, v))
  }

  function toggleMute() {
    if (sink && sink.audio) sink.audio.muted = !sink.audio.muted
  }

  function setMicVolume(v) {
    if (!source || !source.audio) return
    source.audio.muted = false
    source.audio.volume = Math.max(0, Math.min(1, v))
  }

  function toggleMic() {
    if (source && source.audio) source.audio.muted = !source.audio.muted
  }

  function setBrightness(v) {
    var pct = Math.round(Math.max(0.01, Math.min(1, v)) * 100)
    brightness = pct / 100
    Quickshell.execDetached(["brightnessctl", "set", pct + "%"])
  }

  function toggleDnd() {
    dndActive = !dndActive
    Quickshell.execDetached(["omarchy-shell", "notifications", "toggleDnd"])
  }

  // Omarchy keeps hyprsunset running and only changes its temperature.
  function toggleNight() {
    nightActive = !nightActive
    Quickshell.execDetached(["omarchy-toggle-nightlight"])
  }

  function sessionAction(name, cmd) {
    if (armed === name) {
      armed = ""
      panel.host.settingsOpen = false
      Quickshell.execDetached(cmd)
    } else {
      armed = name
      disarmTimer.restart()
    }
  }

  onActiveChanged: {
    if (active) {
      if (panel.host.settingsSection !== "") {
        expanded = panel.host.settingsSection
        panel.host.settingsSection = ""
      }
      if (!netStatusProc.running) netStatusProc.running = true
      if (!brightnessProc.running) brightnessProc.running = true
      if (!nightProbeProc.running) nightProbeProc.running = true
      if (!historyReadProc.running) historyReadProc.running = true
    } else {
      expanded = ""
      armed = ""
      if (btAdapter) btAdapter.discovering = false
    }
  }

  Timer { id: disarmTimer; interval: 3000; onTriggered: panel.armed = "" }
  Timer { id: btPowerTimer; interval: 400; onTriggered: if (panel.btAdapter) panel.btAdapter.enabled = true }
  Timer { id: netRefreshTimer; interval: 900; onTriggered: if (!netStatusProc.running) netStatusProc.running = true }

  FileView {
    path: panel.host.home + "/.local/state/omarchy/notifications.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try { panel.dndActive = JSON.parse(text() || "{}").dnd === true } catch (e) { panel.dndActive = false }
    }
    onFileChanged: reload()
  }

  Process {
    id: netStatusProc
    command: [
      "sh", "-c",
      "nmcli -t -f WIFI radio 2>/dev/null; echo '---'; nmcli -t -f TYPE,STATE,CONNECTION device 2>/dev/null"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parts = String(text || "").split("---\n")
        panel.wifiEnabled = (parts[0] || "").trim() !== "disabled"
        var ssid = "", eth = ""
        var lines = (parts[1] || "").trim().split("\n")
        for (var i = 0; i < lines.length; i++) {
          var f = panel.parseNmcliFields(lines[i])
          if (f[1] === "connected") {
            if (f[0] === "wifi") ssid = f[2] || ""
            else if (f[0] === "ethernet") eth = f[2] || "Ethernet"
          }
        }
        panel.activeSsid = ssid
        panel.activeEthernet = eth
      }
    }
  }

  Process {
    id: brightnessProc
    command: ["brightnessctl", "-m"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var f = String(text || "").trim().split(",")
        if (f.length >= 5 && parseInt(f[4]) > 0) {
          panel.brightness = parseInt(f[2]) / parseInt(f[4])
          panel.brightnessAvailable = true
        }
      }
    }
  }

  Process {
    id: nightProbeProc
    command: ["omarchy-toggle-nightlight", "--status"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { panel.nightActive = JSON.parse(text).enabled === true } catch (e) { panel.nightActive = false }
      }
    }
  }

  Process {
    id: historyReadProc
    command: [
      "python3", "-c",
      "import glob, json, os\n" +
      "p = os.path.expanduser('~/.local/state/omarchy/notifications/history/*.json')\n" +
      "files = sorted(glob.glob(p), key=os.path.getmtime, reverse=True)[:6]\n" +
      "out = []\n" +
      "for f in files:\n" +
      "  try:\n" +
      "    with open(f) as fh: out.append(json.load(fh))\n" +
      "  except Exception: pass\n" +
      "print(json.dumps(out))"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { panel.notifHistory = JSON.parse(String(text || "[]")) || [] }
        catch (e) { panel.notifHistory = [] }
      }
    }
  }

  Timer {
    interval: 4000
    running: panel.active
    repeat: true
    onTriggered: {
      if (!netStatusProc.running) netStatusProc.running = true
      if (!historyReadProc.running) historyReadProc.running = true
    }
  }

  visible: progress > 0.001
  screen: host.focusedScreen
  anchors { top: true; right: true }
  margins.right: attached ? -seamOverlap : 0
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: 0
  implicitWidth: bodyWidth + seamOverlap + 2 + pad
  implicitHeight: bodyHeight + 2 * flare + 16
  color: "transparent"
  surfaceFormat.opaque: false
  WlrLayershell.namespace: "omarchy-nihil-settings"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  mask: Region { item: hit }

  HyprlandFocusGrab {
    active: panel.active
    windows: [panel]
    onCleared: panel.host.settingsOpen = false
  }

  Item {
    id: hit
    x: panel.width - panel.seamOverlap - panel.pad - panel.w
    y: panel.flare + 4
    width: panel.w + panel.seamOverlap
    height: panel.bodyHeight
  }

  // Плавающая карточка (бар не рамка Nihil): как дашборд — материал стиля (StyleCard) или
  // скруглённая карточка с рамкой и тенью бара (BarStyle).
  readonly property real cardRadius: Math.min(panel.host.panelStyle.cornerRadius, panel.w / 2)
  StyleCard {
    visible: !panel.attached && panel.host.panelStyle.card && panel.w > 1
    style: panel.host.panelStyle
    seed: 13
    x: hit.x; y: hit.y; width: panel.w; height: panel.bodyHeight
    radius: panel.cardRadius
  }
  Rectangle {
    visible: !panel.attached && !panel.host.panelStyle.card && panel.w > 1
    x: hit.x; y: hit.y; width: panel.w; height: panel.bodyHeight
    radius: panel.cardRadius
    color: panel.host.panelStyle.color
    border.width: Math.max(1, panel.host.panelStyle.borderWidth)
    border.color: panel.host.panelStyle.borderWidth > 0 ? panel.host.panelStyle.borderColor : Nihil.Palette.line
    layer.enabled: panel.host.panelStyle.shadowOn
    layer.effect: MultiEffect {
      shadowEnabled: true; shadowColor: "#000000"
      shadowOpacity: panel.host.panelStyle.shadowOpacity; shadowBlur: panel.host.panelStyle.shadowBlur
      shadowVerticalOffset: 3 * panel.host.panelStyle.lift
    }
  }

  // Вырастает из правой рамки (бар — рамка Nihil).
  Shape {
    id: panelShape
    visible: panel.attached
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    readonly property real baseX: panel.attached ? panel.width - panel.seamOverlap + 0.5 : panel.width - 0.5
    readonly property real leftX: panel.width - panel.seamOverlap - panel.w
    readonly property real topY: hit.y
    readonly property real bottomY: hit.y + hit.height
    readonly property real fx: Math.min(panel.flare, panel.w)
    readonly property real cr: Math.max(0, Math.min(panel.cornerRadius, (panel.w - fx) / 2))

    // Drawer in the bar colour growing leftward from the right frame bezel.
    ShapePath {
      fillColor: panel.host.panelStyle.color
      strokeWidth: -1
      startX: panel.width
      startY: panelShape.topY - panel.flare

      PathLine { x: panelShape.baseX; y: panelShape.topY - panel.flare }
      PathArc {
        x: panelShape.baseX - panelShape.fx
        y: panelShape.topY
        radiusX: Math.max(0.01, panelShape.fx)
        radiusY: Math.max(0.01, panel.flare)
        direction: PathArc.Counterclockwise
      }
      PathLine { x: panelShape.leftX + panelShape.cr; y: panelShape.topY }
      PathArc {
        x: panelShape.leftX
        y: panelShape.topY + panelShape.cr
        radiusX: Math.max(0.01, panelShape.cr)
        radiusY: Math.max(0.01, panelShape.cr)
        direction: PathArc.Counterclockwise
      }
      PathLine { x: panelShape.leftX; y: panelShape.bottomY - panelShape.cr }
      PathArc {
        x: panelShape.leftX + panelShape.cr
        y: panelShape.bottomY
        radiusX: Math.max(0.01, panelShape.cr)
        radiusY: Math.max(0.01, panelShape.cr)
        direction: PathArc.Counterclockwise
      }
      PathLine { x: panelShape.baseX - panelShape.fx; y: panelShape.bottomY }
      PathArc {
        x: panelShape.baseX
        y: panelShape.bottomY + panel.flare
        radiusX: Math.max(0.01, panelShape.fx)
        radiusY: Math.max(0.01, panel.flare)
        direction: PathArc.Counterclockwise
      }
      PathLine { x: panel.width; y: panelShape.bottomY + panel.flare }
    }

    // 1px hairline: open-right when attached (joins ScreenBorder's right inner hairline),
    // closed for a floating card.
    ShapePath {
      fillColor: "transparent"
      strokeColor: panel.host.panelStyle.borderWidth > 0 ? panel.host.panelStyle.borderColor : Nihil.Palette.line
      strokeWidth: panel.w > 1 ? 1 : -1
      startX: panelShape.baseX
      startY: panelShape.topY - panel.flare

      PathArc {
        x: panelShape.baseX - panelShape.fx
        y: panelShape.topY
        radiusX: Math.max(0.01, panelShape.fx)
        radiusY: Math.max(0.01, panel.flare)
        direction: PathArc.Counterclockwise
      }
      PathLine { x: panelShape.leftX + panelShape.cr; y: panelShape.topY }
      PathArc {
        x: panelShape.leftX
        y: panelShape.topY + panelShape.cr
        radiusX: Math.max(0.01, panelShape.cr)
        radiusY: Math.max(0.01, panelShape.cr)
        direction: PathArc.Counterclockwise
      }
      PathLine { x: panelShape.leftX; y: panelShape.bottomY - panelShape.cr }
      PathArc {
        x: panelShape.leftX + panelShape.cr
        y: panelShape.bottomY
        radiusX: Math.max(0.01, panelShape.cr)
        radiusY: Math.max(0.01, panelShape.cr)
        direction: PathArc.Counterclockwise
      }
      PathLine { x: panelShape.baseX - panelShape.fx; y: panelShape.bottomY }
      PathArc {
        x: panelShape.baseX
        y: panelShape.bottomY + panel.flare
        radiusX: Math.max(0.01, panelShape.fx)
        radiusY: Math.max(0.01, panel.flare)
        direction: PathArc.Counterclockwise
      }
      PathLine { x: panelShape.baseX; y: panel.attached ? panelShape.bottomY + panel.flare : panelShape.topY - panel.flare }
    }
  }



  Item {
    x: hit.x
    y: hit.y
    width: panel.w
    height: panel.bodyHeight
    clip: true
    opacity: panel.contentReveal
    focus: panel.active
    Keys.onEscapePressed: panel.host.settingsOpen = false

    Flickable {
      anchors.fill: parent
      anchors.topMargin: 22
      anchors.bottomMargin: 22
      anchors.leftMargin: 24
      anchors.rightMargin: 22
      width: panel.bodyWidth - 46
      contentHeight: col.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      ColumnLayout {
        id: col
        width: panel.bodyWidth - 46
        spacing: 18

        // Header
        RowLayout {
          Layout.fillWidth: true

          Nihil.Label { text: panel.host.tr("CONTROL PANEL", "ПАНЕЛЬ") }
          Item { Layout.fillWidth: true }
          Nihil.Label {
            text: panel.activeSsid || panel.activeEthernet || panel.host.tr("OFFLINE", "ОФЛАЙН")
          }
        }

        // 3x2 Circular Tiles
        GridLayout {
          Layout.fillWidth: true
          columns: 3
          rowSpacing: 8
          columnSpacing: 0

          Nihil.Tile {
            Layout.alignment: Qt.AlignHCenter
            glyph: panel.wifiEnabled ? String.fromCodePoint(0xF05A9) : String.fromCodePoint(0xF05AA)
            label: "WI-FI"
            active: panel.wifiEnabled
            expandable: true
            expanded: panel.expanded === "wifi"
            onToggled: panel.setWifiRadio(!panel.wifiEnabled)
            onExpand: panel.toggleSection("wifi")
          }

          Nihil.Tile {
            Layout.alignment: Qt.AlignHCenter
            glyph: panel.btEnabled ? String.fromCodePoint(0xF00AF) : String.fromCodePoint(0xF00B2)
            label: "BT"
            active: panel.btEnabled
            expandable: true
            expanded: panel.expanded === "bt"
            onToggled: panel.toggleBluetooth()
            onExpand: panel.toggleSection("bt")
          }

          Nihil.Tile {
            Layout.alignment: Qt.AlignHCenter
            glyph: String.fromCodePoint(0xF04C3)
            label: panel.host.tr("AUDIO", "ЗВУК")
            active: !panel.muted
            expandable: true
            expanded: panel.expanded === "audio"
            onToggled: panel.toggleMute()
            onExpand: panel.toggleSection("audio")
          }

          Nihil.Tile {
            Layout.alignment: Qt.AlignHCenter
            glyph: panel.micMuted ? String.fromCodePoint(0xF036D) : String.fromCodePoint(0xF036C)
            label: panel.host.tr("MIC", "МИКР.")
            active: !panel.micMuted
            onToggled: panel.toggleMic()
          }

          Nihil.Tile {
            Layout.alignment: Qt.AlignHCenter
            glyph: panel.dndActive ? String.fromCodePoint(0xF009B) : String.fromCodePoint(0xF009A)
            label: "DND"
            active: panel.dndActive
            onToggled: panel.toggleDnd()
          }

          Nihil.Tile {
            Layout.alignment: Qt.AlignHCenter
            glyph: String.fromCodePoint(0xF0594)
            label: panel.host.tr("NIGHT", "НОЧЬ")
            active: panel.nightActive
            onToggled: panel.toggleNight()
          }
        }

        // 24-segment LED Sliders
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 14

          Nihil.SliderRow {
            Layout.fillWidth: true
            glyph: panel.volGlyph(panel.volume, panel.muted)
            value: panel.volume
            muted: panel.muted
            onMoved: function(v) { panel.setVolume(v) }
            onGlyphClicked: panel.toggleMute()
          }

          Nihil.SliderRow {
            Layout.fillWidth: true
            glyph: panel.micMuted ? String.fromCodePoint(0xF036D) : String.fromCodePoint(0xF036C)
            value: panel.micVolume
            muted: panel.micMuted
            onMoved: function(v) { panel.setMicVolume(v) }
            onGlyphClicked: panel.toggleMic()
          }

          Nihil.SliderRow {
            Layout.fillWidth: true
            visible: panel.brightnessAvailable
            glyph: String.fromCodePoint(0xF00E0)
            value: panel.brightness
            onMoved: function(v) { panel.setBrightness(v) }
          }
        }

        // Раскрытые Wi-Fi / Bluetooth / звук — возможности панелей Omarchy (nihil/*Section.qml).
        // Loader: секция живёт (сканирует, опрашивает) только пока раскрыта; без клонов
        // kamradsmeshnyavy.network/bluetooth/audio (их Model.js) она просто не загрузится.
        Loader {
          Layout.fillWidth: true
          active: panel.expanded !== ""
          visible: active && status === Loader.Ready
          source: panel.expanded === "wifi" ? "nihil/WifiSection.qml"
            : panel.expanded === "bt" ? "nihil/BtSection.qml"
            : panel.expanded === "audio" ? "nihil/AudioSection.qml" : ""
          onLoaded: item.panel = panel
        }

        // Notification history
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 8

          RowLayout {
            Layout.fillWidth: true
            Nihil.Label {
              text: panel.host.tr("NOTIFICATIONS", "УВЕДОМЛЕНИЯ") + " (" + panel.notifHistory.length + ")"
            }
            Item { Layout.fillWidth: true }
            Nihil.PillButton {
              text: panel.host.tr("REPLAY", "ПОВТОР")
              visible: panel.notifHistory.length > 0
              onClicked: Quickshell.execDetached(["omarchy-shell", "notifications", "showHistory"])
            }
          }

          Repeater {
            model: panel.notifHistory

            Rectangle {
              required property var modelData
              Layout.fillWidth: true
              implicitHeight: histCol.implicitHeight + 20
              radius: Nihil.Finish.nihil ? 14 : Nihil.Finish.radius
              color: Nihil.Palette.surface
              border.width: 1
              border.color: Number(modelData.urgency) === 2 ? Nihil.Palette.danger : Nihil.Palette.unlit

              ColumnLayout {
                id: histCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                spacing: 3

                RowLayout {
                  Layout.fillWidth: true
                  spacing: 6

                  Rectangle {
                    visible: Number(modelData.urgency) === 2
                    width: 6; height: 6; radius: 3
                    color: Nihil.Palette.danger
                  }

                  Nihil.Label {
                    Layout.fillWidth: true
                    text: String(modelData.app || "SYSTEM")
                  }
                }

                Nihil.Txt {
                  Layout.fillWidth: true
                  visible: String(modelData.summary || "") !== ""
                  text: String(modelData.summary || "")
                  font.pixelSize: 13
                  font.weight: Font.Medium
                }

                Nihil.Txt {
                  Layout.fillWidth: true
                  visible: String(modelData.body || "") !== ""
                  text: String(modelData.body || "")
                  font.pixelSize: 12
                  color: Nihil.Palette.dim
                  maximumLineCount: 2
                }
              }
            }
          }

          Nihil.Label {
            visible: panel.notifHistory.length === 0
            text: panel.dndActive
              ? panel.host.tr("DO NOT DISTURB IS ON", "НЕ БЕСПОКОИТЬ ВКЛЮЧЕНО")
              : panel.host.tr("NOTHING NEW", "ПУСТО")
          }
        }

        // Session actions (2-click red confirm)
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 10

          Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Nihil.Palette.line
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Nihil.CircleButton {
              glyph: String.fromCodePoint(0xF033E)
              onClicked: {
                panel.host.settingsOpen = false
                Quickshell.execDetached(["omarchy-system-lock"])
              }
            }
            Nihil.CircleButton {
              glyph: String.fromCodePoint(0xF04B2)
              onClicked: {
                panel.host.settingsOpen = false
                Quickshell.execDetached(["systemctl", "suspend"])
              }
            }
            Nihil.CircleButton {
              glyph: String.fromCodePoint(0xF0343)
              filled: panel.armed === "logout"
              danger: panel.armed === "logout"
              onClicked: panel.sessionAction("logout", ["omarchy-system-logout"])
            }
            Nihil.CircleButton {
              glyph: String.fromCodePoint(0xF0709)
              filled: panel.armed === "reboot"
              danger: panel.armed === "reboot"
              onClicked: panel.sessionAction("reboot", ["omarchy-system-reboot"])
            }
            Nihil.CircleButton {
              glyph: String.fromCodePoint(0xF0425)
              danger: true
              filled: panel.armed === "power"
              onClicked: panel.sessionAction("power", ["omarchy-system-shutdown"])
            }

            Item { Layout.fillWidth: true }

            Nihil.Label {
              visible: panel.armed !== ""
              text: panel.host.tr("CLICK AGAIN", "ЕЩЁ РАЗ")
              color: Nihil.Palette.danger
            }
          }
        }
      }
    }
  }
}

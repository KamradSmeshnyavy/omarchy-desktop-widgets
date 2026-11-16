import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire

// Шкала громкости NieR у левого края — по мотивам VolumeBar из Unit-3 (samyns/Unit-3, MIT, widgets/VolumeBar.qml;
// размеры и цвета оттуда): 30 сегментов в рамке 40 × 420 на тёмном фоне, заполненные — шире, текущий — самый широкий,
// пустые — точки; без звука — красные; сверху «NN%» / «MUTE». Выезжает при наведении на левый край экрана (здесь —
// полоса 3 px, у него 65 px перехватывали бы щелчки по окнам) и при каждом изменении громкости; клик / тяга — задать,
// колесо — ±8 %. Только у райса Unit-3 (rice === "unit3") или при nierVolume: true в widgets.json.
Scope {
  id: root
  required property var host
  readonly property bool on: host.value("nierVolume") === true || (host.value("nierVolume") !== false && host.rice === "unit3")

  readonly property int segments: 30
  readonly property int barWidth: 40
  readonly property int barHeight: 420
  readonly property color colFilled: "#a89a7e"
  readonly property color colEmpty: "#c8b89a"
  readonly property color colBg: "#0f0d0a"

  readonly property PwNode sink: Pipewire.defaultAudioSink
  PwObjectTracker { objects: [root.sink] }
  readonly property real volume: sink && sink.audio ? Math.min(1, sink.audio.volume) : 0
  readonly property bool muted: !!(sink && sink.audio && sink.audio.muted)
  function setVolume(v) { if (sink && sink.audio) { sink.audio.muted = false; sink.audio.volume = Math.max(0, Math.min(1, v)) } }

  property bool pulse: false
  onVolumeChanged: if (on) { pulse = true; pulseTimer.restart() }
  onMutedChanged: if (on) { pulse = true; pulseTimer.restart() }
  Timer { id: pulseTimer; interval: 1400; onTriggered: root.pulse = false }

  PanelWindow {
    id: panel
    visible: root.on
    screen: root.host.focusedScreen
    anchors.left: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "omarchy-nier-volume"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    readonly property bool revealed: edge.containsMouse || barMA.containsMouse || barMA.pressed || hideTimer.running || root.pulse
    implicitWidth: revealed ? 18 + root.barWidth + 10 : 3
    implicitHeight: root.barHeight + 40
    margins.top: screen ? (screen.height - implicitHeight) / 2 : 0

    Timer { id: hideTimer; interval: 400 }

    MouseArea {
      id: edge
      width: 3; height: parent.height
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
      onExited: hideTimer.restart()
    }

    Item {
      id: bar
      width: root.barWidth; height: root.barHeight
      anchors.verticalCenter: parent.verticalCenter
      x: panel.revealed ? 18 : -root.barWidth
      opacity: panel.revealed ? 1 : 0
      Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
      Behavior on opacity { NumberAnimation { duration: 220 } }

      Rectangle { anchors.fill: parent; color: root.colBg; opacity: 0.55; border.color: root.colFilled; border.width: 1 }
      Column {
        anchors.fill: parent; anchors.margins: 6; spacing: 2
        Repeater {
          model: root.segments
          Item {
            width: parent.width
            height: (root.barHeight - 12 - (root.segments - 1) * 2) / root.segments
            readonly property real lvl: 1 - index / (root.segments - 1)
            readonly property bool filled: root.volume >= lvl - 0.0001
            readonly property bool active: filled && root.volume < lvl + 1 / (root.segments - 1) - 0.0001
            Rectangle {
              anchors.centerIn: parent
              width: parent.active ? 22 : parent.filled ? 14 : 4
              height: parent.active ? 5 : parent.filled ? 3 : 4
              radius: parent.filled ? 1 : 0
              color: parent.filled ? (root.muted ? "#6e2a2a" : root.colFilled) : root.colEmpty
              Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
              Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
              Behavior on color { ColorAnimation { duration: 220 } }
            }
          }
        }
      }
      MouseArea {
        id: barMA
        anchors.fill: parent
        hoverEnabled: true
        function toVol(y) { return Math.max(0, Math.min(1, 1 - (y - 6) / (height - 12))) }
        onExited: hideTimer.restart()
        onPressed: function(e) { root.setVolume(toVol(e.y)) }
        onPositionChanged: function(e) { if (pressed) root.setVolume(toVol(e.y)) }
        onWheel: function(e) { root.setVolume(root.volume + (e.angleDelta.y > 0 ? 0.08 : -0.08)); hideTimer.restart() }
      }
      Text {
        anchors { top: parent.top; topMargin: -16; horizontalCenter: parent.horizontalCenter }
        text: root.muted ? "MUTE" : Math.round(root.volume * 100) + "%"
        font.family: Qt.fontFamilies().indexOf("Share Tech Mono") !== -1 ? "Share Tech Mono" : "monospace"
        font.pixelSize: 9; font.letterSpacing: 2
        color: root.colFilled; opacity: 0.8
      }
    }
  }
}

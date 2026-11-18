import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Дашборд Space на весь экран — как его Home (Space/home/Home.qml, github.com/elifouts/Dotfiles, GPL-3.0; облик —
// space/home.png): обои под размытием и тенью, поверх — визор DashSpace в режиме full (уголки по углам экрана,
// часы сверху, плашки колонками у краёв). Открывается тем же dashboardOpen, когда dashStyle — space (обычное окно
// дашборда тогда не показывается). Esc, правый клик или клик мимо плашек — закрыть. В покое не рисует: часы тикают
// раз в секунду, анимации — только на открытии.
PanelWindow {
  id: win
  required property var host
  readonly property bool on: host.dashboardOpen && String(host.value("dashStyle")) === "space"

  property real rise: 0
  property real fade: 0
  visible: fade > 0.001
  screen: host.focusedScreen
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  surfaceFormat.opaque: false
  WlrLayershell.namespace: "omarchy-dashboard"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: on ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  onOnChanged: {
    if (on) { wall.source = ""; wall.source = "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/current/background"; closing.stop(); opening.restart() }
    else { opening.stop(); closing.restart() }
  }
  ParallelAnimation {
    id: opening
    NumberAnimation { target: win; property: "fade"; to: 1; duration: 320; easing.type: Easing.OutCubic }
    SequentialAnimation {
      PauseAnimation { duration: 120 }
      NumberAnimation { target: win; property: "rise"; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }
    }
  }
  ParallelAnimation {
    id: closing
    NumberAnimation { target: win; property: "fade"; to: 0; duration: 240; easing.type: Easing.InCubic }
    NumberAnimation { target: win; property: "rise"; to: 0; duration: 240 }
  }

  // обои под размытием
  Image {
    id: wall
    anchors.fill: parent
    fillMode: Image.PreserveAspectCrop
    sourceSize.width: 960
    asynchronous: true
    cache: false
    visible: false
  }
  MultiEffect {
    anchors.fill: parent
    source: wall
    opacity: win.fade
    blurEnabled: true
    blur: 1
    blurMax: 48
    brightness: -0.18
    saturation: -0.1
  }
  Rectangle { anchors.fill: parent; color: Qt.rgba(win.host.background.r, win.host.background.g, win.host.background.b, 0.45); opacity: win.fade }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: win.host.dashboardOpen = false
  }

  Item {
    id: body
    anchors.fill: parent
    opacity: win.fade
    focus: win.on
    Keys.onEscapePressed: win.host.dashboardOpen = false
    Keys.onPressed: function(e) { if (keyNav.handle(e)) e.accepted = true }
    KeyNav { id: keyNav; anchors.fill: parent; z: 999; scope: parent; active: win.on; ring: win.host.accent }
    DashSpace {
      anchors.fill: parent
      full: true
      host: win.host
      rise: win.rise
    }
  }
}

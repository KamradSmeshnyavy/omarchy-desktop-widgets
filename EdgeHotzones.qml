import QtQuick
import Quickshell
import Quickshell.Wayland

// Optional screen-edge dwell hotzones (enabled via widgets.json `edgeHover: true`):
//   - Top center    -> opens Dashboard
//   - Top-right     -> opens Settings Panel
//   - Bottom center -> opens Launcher
PanelWindow {
  id: zones

  required property var host

  readonly property bool enabled: host.flag("edgeHover")
    && !host.dashboardOpen
    && !host.settingsOpen
    && !host.powerOpen
    && !host.overviewOpen

  visible: enabled && screen !== null
  screen: host.focusedScreen
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  surfaceFormat.opaque: false
  WlrLayershell.namespace: "omarchy-edge-hotzones"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  mask: Region {
    regions: [
      Region { item: topCenter },
      Region { item: topRight },
      Region { item: bottomCenter }
    ]
  }

  MouseArea {
    id: topCenter
    x: Math.round((zones.width - width) / 2)
    y: 0
    width: Math.min(440, zones.width * 0.35)
    height: 5
    hoverEnabled: true
    onContainsMouseChanged: if (containsMouse) topTimer.restart(); else topTimer.stop()
  }

  Timer {
    id: topTimer
    interval: 300
    onTriggered: if (topCenter.containsMouse && zones.enabled) zones.host.dashboardOpen = true
  }

  MouseArea {
    id: topRight
    x: zones.width - width
    y: 0
    width: 120
    height: 12
    hoverEnabled: true
    onContainsMouseChanged: if (containsMouse) rightTimer.restart(); else rightTimer.stop()
  }

  Timer {
    id: rightTimer
    interval: 300
    onTriggered: if (topRight.containsMouse && zones.enabled) zones.host.settingsOpen = true
  }

  MouseArea {
    id: bottomCenter
    x: Math.round((zones.width - width) / 2)
    y: zones.height - height
    width: Math.min(440, zones.width * 0.35)
    height: 5
    hoverEnabled: true
    onContainsMouseChanged: if (containsMouse) bottomTimer.restart(); else bottomTimer.stop()
  }

  Timer {
    id: bottomTimer
    interval: 340
    onTriggered: {
      if (bottomCenter.containsMouse && zones.enabled)
        Quickshell.execDetached(["omarchy-menu", "summon", "apps"])
    }
  }
}

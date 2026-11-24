pragma Singleton

import QtQuick
import Quickshell

// Его Space/common/Ui.qml — то, что трогает панель.
Singleton {
  property var target: null
  property string sheet: "core"
  property bool touring: false
  // облик панели, который открыт (Widgets.qml ставит перед открытием): space и vitreus — оба Sheet.qml
  property string skin: ""
}

pragma Singleton

import QtQuick
import Quickshell

// Его Space/common/Ui.qml: только поля, которые трогает карта.
Singleton {
  property bool overview: false
  property bool covered: false
  property bool holdTheme: false
  property bool touring: false
  property var target: null
}

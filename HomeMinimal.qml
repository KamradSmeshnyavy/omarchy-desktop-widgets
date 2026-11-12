import QtQuick
import QtQuick.Effects
import "dotmatrix" as DotMatrix

// Раскладка домашнего экрана «minimal»: только крупные часы, приветствие и дата — внизу слева,
// как на экране блокировки. Без плиток и без кликов.
Item {
  id: m

  required property var host          // Widgets.qml
  required property var homeScreen    // HomeScreen.qml
  readonly property Item hit: null
  readonly property real k: Math.max(0.4, Math.min(2, Number(host.value("homeScale")) || 1))

  Column {
    x: 80 * m.k
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 90 * m.k
    spacing: 4 * m.k
    layer.enabled: true
    layer.effect: MultiEffect {
      shadowEnabled: true; shadowColor: "#000000"; shadowOpacity: 0.6; shadowBlur: 0.9; shadowVerticalOffset: 2
    }
    Text {
      text: Qt.formatTime(m.homeScreen.now, m.host.value("clock24") !== false ? "HH:mm" : "h:mm")
      font.family: m.homeScreen.dot ? DotMatrix.Palette.fontDot : m.host.fontFamily
      font.pixelSize: 168 * m.k
      font.weight: Font.Thin
      color: m.homeScreen.fg
    }
    Text {
      visible: m.host.value("homeGreeting") !== false
      text: m.homeScreen.greeting
      font.family: m.host.fontFamily
      font.pixelSize: 30 * m.k
      font.weight: Font.Light
      color: m.homeScreen.fg
    }
    Text {
      visible: m.host.value("homeDate") !== false
      text: m.host.locale.toString(m.homeScreen.now, "dddd, d MMMM")
      font.family: m.host.fontFamily
      font.pixelSize: 16 * m.k
      color: m.homeScreen.dim
    }
  }
}

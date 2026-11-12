import QtQuick
import QtQuick.Effects
import "dotmatrix" as DotMatrix

// Плитка домашнего экрана (HomeScreen.qml): подложка в материале стиля (как WidgetCard) —
// StyleCard у paper / soft / brutal / bevel / glow / liquid, у DOT-MATRIX — чёрная плитка с контуром,
// иначе скруглённая карточка BarStyle. Сверху — подпись, крупное значение, мелкая строка и полоса.
Item {
  id: tile

  required property var host          // Widgets.qml
  property string icon: ""
  property string label: ""
  property string value: ""
  property string detail: ""
  property real fill: -1              // 0..1 — полоса снизу, < 0 — без неё
  property bool alert: false
  property int seed: 1
  signal clicked()
  property bool clickable: false

  readonly property var style: host.deskStyle
  readonly property bool dot: host.dotmatrixWidgets
  readonly property color fg: dot ? DotMatrix.Palette.fg : host.foreground
  readonly property color dim: dot ? DotMatrix.Palette.dim : Qt.rgba(host.foreground.r, host.foreground.g, host.foreground.b, 0.6)
  readonly property color accent: alert ? (dot ? DotMatrix.Palette.signal : host.palette.red ? Qt.color(host.palette.red) : "#e06c75")
    : dot ? DotMatrix.Palette.fg : host.accent
  readonly property real r: dot ? 18 : Math.min(style.cornerRadius, height / 3)

  Rectangle {
    visible: tile.dot
    anchors.fill: parent
    radius: tile.r
    color: DotMatrix.Palette.bg
    border.width: 1
    border.color: DotMatrix.Palette.line
  }
  StyleCard {
    visible: !tile.dot && tile.style.card
    anchors.fill: parent
    style: tile.style
    seed: tile.seed
    tape: false
    radius: tile.r
  }
  Rectangle {
    visible: !tile.dot && !tile.style.card
    anchors.fill: parent
    radius: tile.r
    color: tile.style.color
    border.width: Math.max(1, tile.style.borderWidth)
    border.color: tile.style.borderWidth > 0 ? tile.style.borderColor : Qt.rgba(tile.host.foreground.r, tile.host.foreground.g, tile.host.foreground.b, 0.12)
    layer.enabled: tile.style.shadowOn
    layer.effect: MultiEffect {
      shadowEnabled: true; shadowColor: "#000000"
      shadowOpacity: tile.style.shadowOpacity * 0.8; shadowBlur: tile.style.shadowBlur
      shadowVerticalOffset: 3 * tile.style.lift
    }
  }
  Rectangle {
    anchors.fill: parent
    radius: tile.r
    color: tile.fg
    opacity: mouse.containsMouse && tile.clickable ? 0.06 : 0
    Behavior on opacity { NumberAnimation { duration: 120 } }
  }

  Column {
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
    spacing: 4
    Row {
      spacing: 8
      Text {
        visible: tile.icon !== ""
        text: tile.icon
        font.family: tile.host.iconFamily
        font.pixelSize: 14
        color: tile.accent
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        text: tile.dot ? tile.label.toUpperCase() : tile.label
        font.family: tile.dot ? DotMatrix.Palette.fontLabel : tile.host.fontFamily
        font.pixelSize: 12
        font.letterSpacing: tile.dot ? 1.5 : 0.3
        color: tile.dim
        anchors.verticalCenter: parent.verticalCenter
      }
    }
    Text {
      width: parent.width
      text: tile.value
      elide: Text.ElideRight
      font.family: tile.dot ? DotMatrix.Palette.fontDot : tile.host.fontFamily
      font.pixelSize: tile.value.length > 9 ? 20 : 30
      font.weight: Font.DemiBold
      color: tile.alert ? tile.accent : tile.fg
    }
    Text {
      width: parent.width
      visible: tile.detail !== ""
      text: tile.detail
      elide: Text.ElideRight
      font.family: tile.dot ? DotMatrix.Palette.fontLabel : tile.host.fontFamily
      font.pixelSize: 12
      color: tile.dim
    }
  }

  // Полоса значения: у DOT-MATRIX — ряд точек, иначе тонкая линия.
  Item {
    visible: tile.fill >= 0
    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 16 }
    height: 6
    Rectangle {
      visible: !tile.dot
      anchors.fill: parent
      radius: 3
      color: Qt.rgba(tile.fg.r, tile.fg.g, tile.fg.b, 0.12)
      Rectangle {
        width: parent.width * Math.max(0, Math.min(1, tile.fill))
        height: parent.height
        radius: 3
        color: tile.accent
        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
      }
    }
    Row {
      visible: tile.dot
      spacing: 4
      Repeater {
        model: Math.max(1, Math.floor((parent.parent.width + 4) / 10))
        Rectangle {
          required property int index
          width: 6; height: 6; radius: 3
          color: index < Math.round(tile.fill * Math.floor((parent.parent.width + 4) / 10)) ? tile.accent : DotMatrix.Palette.unlit
        }
      }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    enabled: tile.clickable
    cursorShape: tile.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: tile.clicked()
  }
}

import QtQuick
import QtQuick.Effects
import "dotmatrix" as DotMatrix

// Подложка виджета рабочего стола в материале стиля Customizer (widgetStyle = style): ставится
// под виджет `target` с полями `pad`. Материал — как у дашборда: StyleCard (бумага, рельеф,
// брутализм, кант, неон) или скруглённая карточка BarStyle (flat, стекло, fluent) с рамкой и тенью.
Item {
  id: card

  required property var host          // Widgets.qml
  required property Item target
  property int pad: 16
  property int seed: 1
  // У виджета своя карточка DOT-MATRIX (плеер) — подложку DOT-MATRIX не рисовать.
  property bool ownDotmatrixCard: false
  // жидкое стекло: слой окна виджетов (место на экране — у Hyprland) и лежит ли он под окнами
  property string glassNs: "omarchy-widgets"
  property bool glassBelowWin: true
  readonly property var style: host.deskStyle
  readonly property bool dotmatrixCard: host.dotmatrixWidgets && !ownDotmatrixCard

  // у виджета своё стекло (часы vitreus) — подложка не нужна
  property bool noCard: false
  visible: !noCard && (host.styledWidgets || dotmatrixCard) && target && target.visible && target.width > 0
  // DOT-MATRIX: карточки одной ширины (320, как в NIHIL) — колонка ровная; добор — к центру экрана.
  readonly property real baseWidth: target ? target.width + 2 * pad : 0
  readonly property real extra: dotmatrixCard ? Math.max(0, 320 - baseWidth) : 0
  readonly property bool leftHalf: target && parent ? target.x + target.width / 2 < parent.width / 2 : true
  // масштаб виджета (DirectGrab, от центра)
  property real s: 1
  x: target ? target.x + target.width * (1 - s) / 2 - pad - (leftHalf ? 0 : extra) : 0
  y: target ? target.y + target.height * (1 - s) / 2 - pad : 0
  width: (target ? target.width * s + 2 * pad : 0) + extra
  height: target ? target.height * s + 2 * pad : 0

  // DOT-MATRIX — как карточки рабочего стола NIHIL: чёрная (фон палитры) плитка с тонким контуром,
  // читается на любых обоях.
  Rectangle {
    visible: card.dotmatrixCard
    anchors.fill: parent
    radius: Math.min(22, height / 2)
    color: DotMatrix.Palette.bg
    border.width: 1
    border.color: DotMatrix.Palette.line
  }

  StyleCard {
    visible: !card.dotmatrixCard && card.style.card
    anchors.fill: parent
    style: card.style
    seed: card.seed
    radius: Math.min(card.style.cornerRadius, card.height / 2)
    // жидкое стекло: окно слоя виджетов на весь экран — место на экране спросить у Hyprland по имени слоя
    glassLayer: card.glassNs
    glassBelow: card.glassBelowWin
  }
  Rectangle {
    visible: !card.dotmatrixCard && !card.style.card
    anchors.fill: parent
    radius: Math.min(card.style.cornerRadius, height / 2)
    color: card.style.color
    border.width: Math.max(1, card.style.borderWidth)
    border.color: card.style.borderWidth > 0 ? card.style.borderColor : Qt.rgba(card.host.foreground.r, card.host.foreground.g, card.host.foreground.b, 0.12)
    layer.enabled: card.style.shadowOn
    layer.effect: MultiEffect {
      shadowEnabled: true; shadowColor: "#000000"
      shadowOpacity: card.style.shadowOpacity; shadowBlur: card.style.shadowBlur
      shadowVerticalOffset: 3 * card.style.lift
    }
  }
}

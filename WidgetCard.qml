import QtQuick
import QtQuick.Effects

// Подложка виджета рабочего стола в материале стиля Customizer (widgetStyle = style): ставится
// под виджет `target` с полями `pad`. Материал — как у дашборда: StyleCard (бумага, рельеф,
// брутализм, кант, неон) или скруглённая карточка BarStyle (flat, стекло, fluent) с рамкой и тенью.
Item {
  id: card

  required property var host          // Widgets.qml
  required property Item target
  property int pad: 16
  property int seed: 1
  readonly property var style: host.deskStyle

  visible: host.styledWidgets && target && target.visible && target.width > 0
  x: target ? target.x - pad : 0
  y: target ? target.y - pad : 0
  width: target ? target.width + 2 * pad : 0
  height: target ? target.height + 2 * pad : 0

  StyleCard {
    visible: card.style.card
    anchors.fill: parent
    style: card.style
    seed: card.seed
    radius: Math.min(card.style.cornerRadius, card.height / 2)
  }
  Rectangle {
    visible: !card.style.card
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

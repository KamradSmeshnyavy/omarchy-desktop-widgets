import QtQuick
import QtQuick.Effects
import "dotmatrix" as DotMatrix
import "glyph" as Glyph

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

  // Слияние с баром / рамкой: края окна, у которых карточка сливается (DesktopLayer.mergeable), и какими из них она
  // касается — те и сливаются (пластик — без контура, с вогнутыми углами; стекло — перешеек вдоль края, внутри рамки не
  // рисуется). Список читает DesktopLayer — места стыков уходят рамке.
  property var mergeable: []
  readonly property real fil: 14
  readonly property var mergeEdges: {
    var out = []
    if (!visible || !parent || !mergeable.length) return out
    var pw = parent.width, ph = parent.height
    if (mergeable.indexOf("top") !== -1 && y <= 0.5) out.push("top")
    if (mergeable.indexOf("bottom") !== -1 && y + height >= ph - 0.5) out.push("bottom")
    if (mergeable.indexOf("left") !== -1 && x <= 0.5) out.push("left")
    if (mergeable.indexOf("right") !== -1 && x + width >= pw - 0.5) out.push("right")
    return out
  }
  // для стекла: полоска у края (перешеек) и всё за краем минус 3 px (вырез) — до двух краёв (угол)
  function strip(e) {
    var e2 = fil + 6, t = 5
    return e === "top" ? Qt.rect(-e2, -t, width + 2 * e2, t) : e === "bottom" ? Qt.rect(-e2, height, width + 2 * e2, t)
      : e === "left" ? Qt.rect(-t, -e2, t, height + 2 * e2) : Qt.rect(width, -e2, t, height + 2 * e2)
  }
  function beyond(e) {
    return e === "top" ? Qt.rect(-4000, -4000, 8000, 4000 - 3) : e === "bottom" ? Qt.rect(-4000, height + 3, 8000, 4000)
      : e === "left" ? Qt.rect(-4000, -4000, 4000 - 3, 8000) : Qt.rect(width + 3, -4000, 4000, 8000)
  }
  readonly property rect none: Qt.rect(0, 0, 0, 0)

  // Карточка райса: у райсов без своего материала (style.json "rice" — Unit-3, Cozytile, Rumda, surface, Glyph) виджет
  // лежит на карточке, как в их дашбордах; у Bruteon (brutal), yami (pixel), Vitreus (стекло) и DOT-MATRIX облик уже
  // даёт материал стиля. Слитая с баром / рамкой карточка остаётся StyleCard — он умеет стыки.
  readonly property string rice: host.rice
  readonly property bool riceCard: host.styledWidgets && !noCard && mergeEdges.length === 0
    && ["unit3", "cozytile", "rumda", "surface", "glyph"].indexOf(rice) !== -1
  readonly property color fg: host.foreground
  readonly property color bg: host.background
  readonly property bool dark: 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b < 0.5
  function mix(a, b, k) { return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, 1) }
  function fa(k) { return Qt.rgba(fg.r, fg.g, fg.b, k) }

  Item {
    id: riceFace
    visible: card.riceCard
    anchors.fill: parent
    layer.enabled: card.riceCard && card.style.shadowOn && card.rice !== "unit3"
    layer.effect: MultiEffect {
      shadowEnabled: true; shadowColor: "#000000"
      shadowOpacity: card.style.shadowOpacity; shadowBlur: card.style.shadowBlur
      shadowVerticalOffset: 3 * card.style.lift
    }

    // Unit-3 — лист NieR: фон на 92 %, черта 1 px (текст 15 %), прямые углы, сетка 20 px и уголки-скобки
    Rectangle {
      visible: card.rice === "unit3"
      anchors.fill: parent
      color: Qt.rgba(card.bg.r, card.bg.g, card.bg.b, 0.92)
      border.width: 1
      border.color: card.fa(0.15)
      clip: true
      Repeater { model: card.rice === "unit3" ? Math.ceil(card.width / 20) : 0; Rectangle { x: index * 20; width: 1; height: card.height; color: card.fa(0.04) } }
      Repeater { model: card.rice === "unit3" ? Math.ceil(card.height / 20) : 0; Rectangle { y: index * 20; width: card.width; height: 1; color: card.fa(0.04) } }
      Repeater {
        model: card.rice === "unit3" ? 4 : 0
        Item {
          required property int index
          readonly property bool atRight: index % 2 === 1
          readonly property bool atBottom: index > 1
          x: atRight ? card.width - 12 - 3 : 3
          y: atBottom ? card.height - 12 - 3 : 3
          width: 12; height: 12
          Rectangle { y: parent.atBottom ? 10.5 : 0; width: 12; height: 1.5; color: card.fa(0.6) }
          Rectangle { x: parent.atRight ? 10.5 : 0; width: 1.5; height: 12; color: card.fa(0.6) }
        }
      }
    }
    // Cozytile — тёмная карточка его дашборда (фон 80 % + текст 6 %), скругление 10
    Rectangle {
      visible: card.rice === "cozytile"
      anchors.fill: parent
      radius: Math.min(10, height / 2)
      color: Qt.rgba(card.bg.r * 0.8 + card.fg.r * 0.06, card.bg.g * 0.8 + card.fg.g * 0.06, card.bg.b * 0.8 + card.fg.b * 0.06, 1)
    }
    // Rumda — блок цвета модуля (фон + текст 13 %) с рамкой 2 px, скругление 6
    Rectangle {
      visible: card.rice === "rumda"
      anchors.fill: parent
      radius: 6
      color: card.mix(card.bg, card.fg, 0.13)
      border.width: 2
      border.color: card.mix(card.bg, card.fg, 0.08)
    }
    // surface — карточка Hub: на шаг светлее (тёмная тема) / темнее (светлая) фона, скругление 10
    Rectangle {
      visible: card.rice === "surface"
      anchors.fill: parent
      radius: Math.min(10, height / 2)
      color: card.dark ? card.mix(card.bg, card.fg, 0.06) : card.mix(card.bg, Qt.color("#000000"), 0.055)
    }
    // Glyph — карточка glyph-rice: s1 с контуром s2, скругление 28
    Rectangle {
      visible: card.rice === "glyph"
      anchors.fill: parent
      radius: Math.min(28, height / 2)
      color: Glyph.GTheme.s1
      border.width: 1
      border.color: Glyph.GTheme.s2
    }
  }

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
    visible: !card.dotmatrixCard && !card.riceCard && card.style.card
    anchors.fill: parent
    style: card.style
    seed: card.seed
    radius: Math.min(card.style.cornerRadius, card.height / 2)
    // жидкое стекло: окно слоя виджетов на весь экран — место на экране спросить у Hyprland по имени слоя
    glassLayer: card.glassNs
    glassBelow: card.glassBelowWin
    mergeEdges: card.mergeEdges
    mergeFillet: card.fil
    glassBleed: card.mergeEdges.length ? card.fil + 14 : 0
    glassJoin: card.mergeEdges.length > 0 ? card.strip(card.mergeEdges[0]) : card.none
    glassJoinK: card.mergeEdges.length > 0 ? card.fil : 0
    glassJoinRadius: 0
    glassJoin2: card.mergeEdges.length > 1 ? card.strip(card.mergeEdges[1]) : card.none
    glassJoin2K: card.fil
    glassCut: card.mergeEdges.length > 0 ? card.beyond(card.mergeEdges[0]) : card.none
    glassCut2: card.mergeEdges.length > 1 ? card.beyond(card.mergeEdges[1]) : card.none
  }
  Rectangle {
    visible: !card.dotmatrixCard && !card.riceCard && !card.style.card
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

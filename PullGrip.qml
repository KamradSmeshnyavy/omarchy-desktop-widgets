import QtQuick

// Ручки отрыва панели от бара (DrawerPull): верхняя полоса с чёрточкой и красный язычок основы Retro (сам язычок рисует
// StyleCard, здесь — только область, за которую его берут). Кладётся в прямоугольник панели (hit). Двойной клик —
// панель обратно к бару. tabItem — в маску окна: язычок выступает над панелью.
Item {
  id: g

  required property var pull
  property bool active: true
  property bool tabShown: false          // язычок Retro виден (не слит верх)
  property bool stripShown: true
  property real stripHeight: 14
  property color ink: "white"
  readonly property alias tabItem: tab
  readonly property bool dragging: stripDrag.active || tabDrag.active

  anchors.fill: parent
  z: 20

  function begin() { g.pull.start(Qt.rect(g.parent.x, g.parent.y, g.parent.width, g.parent.height)) }

  Item {
    id: strip
    visible: g.active && g.stripShown
    anchors { left: parent.left; right: parent.right; top: parent.top }
    height: g.stripHeight
    HoverHandler { cursorShape: stripDrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor }
    Rectangle {
      anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 5 }
      width: Math.min(44, parent.width / 3); height: 4; radius: 2
      color: Qt.rgba(g.ink.r, g.ink.g, g.ink.b, stripDrag.active ? 0.6 : 0.28)
    }
    DragHandler {
      id: stripDrag
      target: null
      dragThreshold: 4
      onActiveChanged: active ? g.begin() : g.pull.end()
      onTranslationChanged: if (active) g.pull.move(translation.x, translation.y)
    }
    TapHandler { onDoubleTapped: g.pull.home() }
  }
  // как в StyleCard: x = min(58, max(12, (w − 78) / 2)), y = −9
  Item {
    id: tab
    visible: g.active && g.tabShown
    x: Math.min(58, Math.max(12, (g.width - 78) / 2)); y: -10
    width: 78; height: 26
    z: 1
    HoverHandler { cursorShape: tabDrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor }
    DragHandler {
      id: tabDrag
      target: null
      dragThreshold: 3
      onActiveChanged: active ? g.begin() : g.pull.end()
      onTranslationChanged: if (active) g.pull.move(translation.x, translation.y)
    }
    TapHandler { onDoubleTapped: g.pull.home() }
  }
}

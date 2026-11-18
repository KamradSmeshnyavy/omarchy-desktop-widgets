import QtQuick

// Рамка Retro CRT (его Retro/common/Box.qml, elifouts/Dotfiles, GPL-3.0): линия 1 px, заголовок врезан в верхнюю
// черту слева («─ SYSTEM ──»), подпись — в нижнюю справа («── ESC-END ─»); double — вторая рамка внутри на 3 px.
Rectangle {
  id: box
  property var pal
  property string title
  property string note
  property bool double: false
  property real fill: 1
  property color ink: pal.line
  color: pal.a(pal.bg, fill)
  Rectangle { visible: box.double; anchors.fill: parent; anchors.margins: 3; color: "transparent"; border.width: 1; border.color: box.ink }
  Rectangle { width: 1; height: parent.height; color: box.ink }
  Rectangle { x: parent.width - 1; width: 1; height: parent.height; color: box.ink }
  Rectangle { width: head.visible ? head.x : parent.width; height: 1; color: box.ink }
  Rectangle { visible: head.visible; x: head.x + head.width; width: parent.width - x; height: 1; color: box.ink }
  Rectangle { y: parent.height - 1; width: tail.visible ? tail.x : parent.width; height: 1; color: box.ink }
  Rectangle { visible: tail.visible; x: tail.x + tail.width; y: parent.height - 1; width: parent.width - x; height: 1; color: box.ink }
  Item {
    id: head
    visible: box.title !== ""
    x: 10; y: -height / 2
    width: headText.implicitWidth + 12; height: headText.implicitHeight
    Rectangle { width: parent.width; height: parent.height / 2; color: box.color }
    CrtType { id: headText; x: 6; pal: box.pal; text: box.title; color: box.pal.accent }
  }
  Item {
    id: tail
    visible: box.note !== ""
    x: parent.width - width - 10; y: parent.height - height / 2
    width: tailText.implicitWidth + 12; height: tailText.implicitHeight
    Rectangle { y: parent.height / 2; width: parent.width; height: parent.height / 2; color: box.color }
    CrtType { id: tailText; x: 6; pal: box.pal; text: box.note; color: box.pal.dim; font.pixelSize: box.pal.size - 3 }
  }
}

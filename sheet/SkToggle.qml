import QtQuick

// Тумблер строкой: подпись слева, переключатель справа; вся строка — цель клавиатуры (Enter / Space).
// Вид — Sk.t.toggle: pill (дорожка с ручкой), capsule (толстая капсула Rumda), check ([x] терминала yami),
// dot (кружок Nothing с красной точкой), led (светодиод DOT-MATRIX), square (плитка Bruteon на жёсткой тени),
// stripe (квадрат-маркер YoRHa).
Item {
  id: tg
  property string label
  property string key
  property bool fallback: true
  property var raises
  readonly property bool on: !!(StoreShared.values[key] ?? fallback)
  readonly property string kind: Sk.s("toggle", "pill")
  readonly property string rowLabel: label
  readonly property string rowValue: on ? "on" : "off"
  readonly property string rowHint: "Enter — on / off · right click — default"
  width: 320
  implicitHeight: Math.max(24, Sk.n("rowH", 26))
  function flip() {
    const r = tg.raises, next = {}
    next[tg.key] = !tg.on
    if (!tg.on && r && StoreShared.values[r.key] < r.min) next[r.key] = r.min
    StoreShared.setMany(next)
  }

  SkLabel { x: 0; width: tg.width - 70; height: parent.height; text: tg.label; faint: !area.containsMouse; lit: false }

  Item {
    id: sw
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: tg.kind === "check" ? chk.implicitWidth : tg.kind === "capsule" ? 42 : tg.kind === "dot" ? 20 : tg.kind === "led" ? 46 : tg.kind === "square" ? 50 : tg.kind === "stripe" ? 52 : 34
    height: tg.kind === "capsule" ? 22 : tg.kind === "square" ? 22 : 18

    // pill / capsule
    Rectangle {
      visible: tg.kind === "pill" || tg.kind === "capsule"
      anchors.fill: parent
      radius: height / 2
      color: tg.on ? Sk.c("accent") : Sk.alpha(Sk.c("ink"), 0.12)
      border.width: tg.kind === "capsule" ? 2 : 1
      border.color: tg.on ? Sk.c("accent") : Sk.alpha(Sk.c("ink"), 0.35)
      Behavior on color { ColorAnimation { duration: 140 } }
      Rectangle {
        width: parent.height - 6; height: width; radius: width / 2
        y: 3
        x: tg.on ? parent.width - width - 3 : 3
        color: tg.on ? Sk.c("onAccent", Sk.ink(Sk.c("accent"))) : Sk.alpha(Sk.c("ink"), 0.6)
        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
      }
    }
    // check: [x]
    Text {
      id: chk
      visible: tg.kind === "check"
      anchors.verticalCenter: parent.verticalCenter
      text: tg.on ? "[x]" : "[ ]"
      color: tg.on ? Sk.c("accent") : Sk.c("dim")
      font.family: Sk.s("font", "monospace"); font.pixelSize: Sk.n("size", 12) + 1
    }
    // dot: кружок, внутри — точка
    Rectangle {
      visible: tg.kind === "dot"
      anchors.centerIn: parent
      width: 18; height: 18; radius: 9
      color: "transparent"
      border.width: 1.5
      border.color: tg.on ? Sk.c("ink") : Sk.alpha(Sk.c("ink"), 0.4)
      Rectangle { anchors.centerIn: parent; width: tg.on ? 8 : 0; height: width; radius: width / 2; color: Sk.c("signal", Sk.c("accent")); Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutBack } } }
    }
    // led: квадратный светодиод и надпись
    Row {
      visible: tg.kind === "led"
      anchors.verticalCenter: parent.verticalCenter
      spacing: 6
      Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: tg.on ? Sk.c("signal", Sk.c("accent")) : Sk.c("unlit", Sk.alpha(Sk.c("ink"), 0.15)) }
      Text { text: tg.on ? "ON" : "OFF"; color: tg.on ? Sk.c("ink") : Sk.c("dim"); font.family: Sk.s("font", "monospace"); font.pixelSize: Sk.n("size", 11); font.letterSpacing: 1.4 }
    }
    // square: плитка на жёсткой тени, нажатая «падает» на тень
    Item {
      visible: tg.kind === "square"
      anchors.fill: parent
      Rectangle { x: 3; y: 3; width: parent.width; height: parent.height; radius: Sk.n("radius", 4); color: Sk.c("shadowColor", "#000000"); visible: !tg.on }
      Rectangle {
        x: tg.on ? 3 : 0; y: tg.on ? 3 : 0
        width: parent.width; height: parent.height; radius: Sk.n("radius", 4)
        color: tg.on ? Sk.c("accent") : Sk.c("card")
        border.width: 2; border.color: Sk.c("ink")
        Behavior on x { NumberAnimation { duration: 90 } }
        Behavior on y { NumberAnimation { duration: 90 } }
        Text { anchors.centerIn: parent; text: tg.on ? "ON" : "OFF"; color: tg.on ? Sk.c("onAccent", Sk.ink(Sk.c("accent"))) : Sk.c("ink"); font.family: Sk.s("font", "monospace"); font.pixelSize: 10; font.bold: true }
      }
    }
    // stripe: квадрат-маркер и слово
    Row {
      visible: tg.kind === "stripe"
      anchors.verticalCenter: parent.verticalCenter
      spacing: 6
      Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 10; height: 10; color: tg.on ? Sk.c("ink") : "transparent"; border.width: 1.5; border.color: Sk.c("ink") }
      Text { text: tg.on ? "ON" : "OFF"; color: Sk.c("ink"); font.family: Sk.s("font", "monospace"); font.pixelSize: Sk.n("size", 11); font.letterSpacing: 1 }
    }
  }

  SkHit {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton
    kbdRadius: Sk.n("radius", 4)
    onHit: tg.flip()
  }
}

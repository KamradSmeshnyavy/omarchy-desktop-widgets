import QtQuick

// Заголовок раздела. Вид — Sk.t.title: rule (текст и линия), comment («# раздел» терминала), sticker (пастельная
// наклейка с контуром и тенью Bruteon), stripe (тёмная полоса YoRHa), dots (точечный шрифт и пунктир DOT-MATRIX),
// plain (только текст).
Item {
  id: ti
  property string text
  property int index: 0
  readonly property string kind: Sk.s("title", "rule")
  width: parent?.width ?? 300
  height: kind === "sticker" ? 30 : kind === "stripe" ? 26 : 24

  // sticker
  Item {
    visible: ti.kind === "sticker"
    width: st.implicitWidth + 22; height: 22
    y: 2
    rotation: [-2, 1.5, -1, 2][ti.index % 4]
    Rectangle { x: 3; y: 3; width: parent.width; height: parent.height; radius: Sk.n("radius", 4); color: Sk.c("shadowColor", "#000000") }
    Rectangle {
      width: parent.width; height: parent.height; radius: Sk.n("radius", 4)
      color: (Sk.t.pastels || ["#ffd98a"])[ti.index % (Sk.t.pastels || [1]).length]
      border.width: 2; border.color: Sk.c("ink")
      Text { id: st; anchors.centerIn: parent; text: ti.text.toUpperCase(); color: "#161110"; font.family: Sk.s("head", Sk.s("font")); font.pixelSize: 11; font.bold: true; font.letterSpacing: 1 }
    }
  }
  // stripe
  Rectangle {
    visible: ti.kind === "stripe"
    width: parent.width; height: 22
    color: Sk.c("ink")
    Row {
      x: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 8
      Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; color: Sk.c("bg") }
      Text { text: ti.text; color: Sk.c("bg"); font.family: Sk.s("head", Sk.s("font")); font.pixelSize: Sk.n("size", 12); font.letterSpacing: 1.5 }
    }
  }
  // comment / rule / dots / plain
  Text {
    id: tt
    visible: ti.kind !== "sticker" && ti.kind !== "stripe"
    anchors.verticalCenter: parent.verticalCenter
    text: ti.kind === "comment" ? "# " + ti.text.toLowerCase() : Sk.cap(ti.text)
    color: ti.kind === "comment" ? Sk.c("dim") : Sk.c("accent")
    font.family: ti.kind === "dots" ? Sk.s("dotFont", Sk.s("head", Sk.s("font"))) : Sk.s("head", Sk.s("font"))
    font.pixelSize: ti.kind === "dots" ? Sk.n("size", 12) + 3 : Sk.n("size", 12) + 1
    font.letterSpacing: Sk.n("spacing", 0) + (ti.kind === "dots" ? 1 : 0)
    font.bold: ti.kind === "rule"
  }
  Rectangle {
    visible: ti.kind === "rule"
    x: tt.implicitWidth + 10; anchors.verticalCenter: parent.verticalCenter
    width: parent.width - x; height: 1
    color: Sk.alpha(Sk.c("ink"), 0.18)
  }
  Row {
    visible: ti.kind === "dots"
    x: tt.implicitWidth + 12; anchors.verticalCenter: parent.verticalCenter
    spacing: 5
    Repeater { model: ti.kind === "dots" && ti.width > 0 ? Math.max(0, Math.floor((ti.width - tt.implicitWidth - 12) / 7)) : 0; Rectangle { width: 2; height: 2; radius: 1; color: Sk.c("line") } }
  }
}

import QtQuick
import qs.Commons as Commons

// Панель настроек Rumda — «песочная тетрадь»: светлый песочный лист в линейку с кольцами переплёта слева,
// заголовки пиксельным Dogica, коричневый текст; справа — вертикальная карамельная пилюля-закладка с кружками
// разделов (выбранный заливается и «вытягивает» язычок к листу). Тумблеры — карамельные капсулы, ползунки — толстые
// скруглённые столбики. Лист появляется, чуть подпрыгнув; разделы листаются вбок. Цвета — от акцента темы
// (как Super+M Rumda): песок = акцент, разбавленный белым, текст — акцент, затемнённый.
SkinWindow {
  id: w
  region: frame
  openMs: 460
  openEasing: Easing.OutBack
  readonly property color acc: Commons.Color.accent
  readonly property color sand: Qt.tint(acc, Qt.rgba(1, 1, 1, 0.72))
  readonly property color sand2: Qt.tint(acc, Qt.rgba(1, 1, 1, 0.55))
  readonly property color brown: Qt.darker(acc, 1.9)
  readonly property string px: Sk.family("Dogica Pixel", "monospace")
  readonly property string mono: Sk.family("JetBrainsMono Nerd Font", "monospace")
  Binding {
    target: Sk
    property: "t"
    value: ({ bg: w.sand, card: w.sand2, ink: w.brown, dim: Sk.alpha(w.brown, 0.62), accent: Qt.darker(w.acc, 1.15), onAccent: w.sand,
              line: Sk.alpha(w.brown, 0.4), sel: w.acc, onSel: w.sand, font: w.mono, head: w.px, size: 12, caps: false, spacing: 0,
              radius: 10, border: 2, shadow: 0, toggle: "capsule", slider: "bar", title: "rule", chip: "fill", popup: "list",
              swatch: "round", swap: "slide", colW: 320, gap: 30, rowH: 26, labelW: 150, ring: w.brown })
  }

  readonly property real pageW: Math.max(420, page.implicitWidth)
  readonly property real pageH: Math.max(300, page.implicitHeight)
  Item {
    id: frame
    width: w.pageW + 140
    height: Math.max(w.pageH + 112, w.tabs.length * 32 + 60)
    x: Math.round((w.width - width) / 2)
    y: Math.round((w.height - height) / 2)
    opacity: Math.min(1, w.k * 3)
    scale: 0.9 + 0.1 * w.k
    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    // лист
    Rectangle {
      id: sheetBg
      x: 0; y: 0
      width: parent.width - 58; height: parent.height
      radius: 18
      color: w.sand
      border.width: 2; border.color: Sk.alpha(w.brown, 0.55)
      // линейка
      Item {
        anchors.fill: parent; anchors.margins: 2
        clip: true
        Repeater {
          model: Math.floor(sheetBg.height / 26)
          Rectangle { required property int index; x: 44; width: sheetBg.width - 60; y: 70 + index * 26 + 25; height: 1; color: Sk.alpha(w.brown, 0.08) }
        }
        Rectangle { x: 52; width: 1; height: parent.height; color: Sk.alpha(w.acc, 0.35) }
      }
      // кольца переплёта
      Column {
        x: -9; y: 24; spacing: (sheetBg.height - 48 - 8 * 18) / 7
        Repeater { model: 8; Rectangle { width: 22; height: 18; radius: 9; color: "transparent"; border.width: 3; border.color: Qt.darker(w.acc, 1.3) } }
      }
      Text { x: 66; y: 22; text: "settings"; color: w.brown; font.family: w.px; font.pixelSize: 14 }
      Text { x: 66 + 120; y: 25; text: "· " + SheetCore.title(w.tab).toLowerCase(); color: Qt.darker(w.acc, 1.2); font.family: w.px; font.pixelSize: 10 }
      Text { anchors.right: parent.right; anchors.rightMargin: 22; y: 25; text: "esc  ?"; color: Sk.alpha(w.brown, 0.45); font.family: w.px; font.pixelSize: 8 }
      SkPage {
        id: page
        x: 66; y: 66
        tab: w.tab
        dir: w.dir
        maxHeight: Math.min(560, w.height - 220)
      }
    }

    // пилюля-закладка
    Rectangle {
      id: pill
      x: parent.width - 50 + (1 - w.k) * 40
      y: (parent.height - height) / 2
      width: 44; height: w.tabs.length * 32 + 16
      radius: 22
      color: Qt.darker(w.acc, 1.25)
      border.width: 2; border.color: w.brown
      Column {
        x: 7; y: 8; spacing: 2
        Repeater {
          model: w.tabs
          Item {
            id: dot
            required property string modelData
            required property int index
            readonly property bool on: w.tab === modelData
            width: 30; height: 30
            // язычок к листу у выбранного
            Rectangle { visible: dot.on; x: -24; y: 9; width: 26; height: 12; radius: 6; color: w.acc }
            Rectangle {
              anchors.fill: parent; radius: 15
              color: dot.on ? w.acc : dm.containsMouse ? Sk.alpha(w.sand, 0.35) : Sk.alpha(w.sand, 0.12)
              border.width: dot.on ? 2 : 0; border.color: w.sand
              Behavior on color { ColorAnimation { duration: 160 } }
              Text { anchors.centerIn: parent; text: SheetCore.icon(dot.modelData); color: dot.on ? w.brown : w.sand; font.family: w.mono; font.pixelSize: 14 }
            }
            SkHit { id: dm; anchors.fill: parent; kbdRadius: 15; property int kbdOrder: 2000000 + dot.index; readonly property string rowLabel: SheetCore.title(dot.modelData); onHit: w.go(dot.modelData) }
          }
        }
      }
    }
  }
  Connections { target: w; function onSearch() { page.search() } }
}

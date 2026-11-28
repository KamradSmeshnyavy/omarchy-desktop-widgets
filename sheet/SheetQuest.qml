import QtQuick
import Quickshell
import ".." as W

// Панель настроек райса Quest (Super+Alt+I) — экран «КОНФИГУРАЦИЯ» ролевой игры: четыре окна-диалога (QuestWin).
// Сверху — заголовок с героем и номером вкладки, слева — вкладки списком команд с рукой-курсором (выбранная — золото
// курсора), справа — страница настроек (SkPage: тумблеры ●/○, шкалы клетками, выбор — списком), снизу — подсказки
// клавиш. Окна раскрываются по вертикали по очереди, как диалоги в игре. Клавиатура и выпадающий список — SkinWindow.
SkinWindow {
  id: w
  region: frame
  openMs: 420
  openEasing: Easing.Linear
  W.QuestPal { id: qp }
  readonly property int tabsW: 200
  function g(i) { return Math.max(0, Math.min(1, w.k * 3 - i * 0.5)) }

  Binding {
    target: Sk
    property: "t"
    value: ({ bg: "transparent", card: qp.alpha(qp.ink, 0.25), ink: qp.text, dim: qp.dim, accent: qp.hi, onAccent: qp.ink,
              line: qp.frame2, sel: qp.alpha(qp.frame, 0.14), font: qp.body, head: qp.font(8), size: 15, caps: false,
              spacing: 0, radius: 2, border: 1, shadow: 0, shadowColor: qp.ink, toggle: "dot", slider: "cells",
              title: "plain", chip: "box", popup: "list", swatch: "square", swap: "type", colW: 300, gap: 18,
              rowH: 32, labelW: 140, ring: qp.hi, knobRadius: 0 })
  }

  Item {
    id: frame
    readonly property real pageH: Math.max(page.implicitHeight, w.tabs.length * 34) + 24
    width: Math.min(w.width - 40, Math.max(900, page.implicitWidth + w.tabsW + 70))
    height: 70 + 8 + pageH + 8 + 44
    x: Math.round((w.width - width) / 2)
    y: Math.round((w.height - height) / 2)
    Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    // ── заголовок ──
    W.QuestWin {
      id: head
      pal: qp
      width: frame.width; height: 70
      transform: Scale { origin.y: head.height / 2; yScale: w.g(0) }
      Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 16
        Image { source: qp.sprite("chest"); smooth: false; width: 40; height: 32; anchors.verticalCenter: parent.verticalCenter }
        Text { anchors.verticalCenter: parent.verticalCenter; text: "КОНФИГУРАЦИЯ"; color: qp.hi; font.family: qp.font(16); font.pixelSize: qp.size(16) }
        Text { anchors.verticalCenter: parent.verticalCenter; text: SheetCore.title(w.tab).toUpperCase(); color: qp.text; font.family: qp.font(8); font.pixelSize: qp.size(8) }
      }
      Text {
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        text: (w.tabs.indexOf(w.tab) + 1) + " / " + w.tabs.length
        color: qp.dim; font.family: qp.font(8); font.pixelSize: qp.size(8)
      }
    }

    // ── вкладки ──
    W.QuestWin {
      id: tabsWin
      pal: qp
      y: head.height + 8
      width: w.tabsW; height: frame.pageH
      transform: Scale { origin.y: tabsWin.height / 2; yScale: w.g(1) }
      Column {
        x: 22; y: 2
        Repeater {
          model: w.tabs
          Item {
            id: tr
            required property string modelData
            required property int index
            readonly property bool on: w.tab === modelData
            width: w.tabsW - 50; height: 34
            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width; elide: Text.ElideRight
              text: SheetCore.title(tr.modelData).toUpperCase()
              color: tr.on ? qp.hi : th.containsMouse ? qp.text : qp.alpha(qp.text, 0.8)
              font.family: qp.font(8); font.pixelSize: qp.size(8)
            }
            SkHit {
              id: th; anchors.fill: parent; kbdRadius: 0
              property int kbdOrder: 2000000 + tr.index
              readonly property string rowLabel: SheetCore.title(tr.modelData)
              readonly property string rowHint: "Enter — открыть · Tab / [ ] — соседняя"
              onHit: w.go(tr.modelData)
            }
          }
        }
      }
      // рука-курсор у выбранной вкладки
      Image {
        source: qp.sprite("hand"); smooth: false
        width: 16; height: 11
        x: 0 + bob
        y: 2 + Math.max(0, w.tabs.indexOf(w.tab)) * 34 + 11
        property real bob: 0
        Behavior on y { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
        SequentialAnimation on bob {
          running: w.k > 0.5; loops: Animation.Infinite
          PauseAnimation { duration: 450 }
          NumberAnimation { to: 3; duration: 1 }
          PauseAnimation { duration: 450 }
          NumberAnimation { to: 0; duration: 1 }
        }
      }
    }

    // ── страница ──
    W.QuestWin {
      id: pageWin
      pal: qp
      x: w.tabsW + 8; y: head.height + 8
      width: frame.width - x; height: frame.pageH
      transform: Scale { origin.y: pageWin.height / 2; yScale: w.g(2) }
      clip: true
      SkPage {
        id: page
        x: 6; y: 6
        tab: w.tab
        dir: w.dir
        maxHeight: Math.min(560, w.height - 260)
      }
    }

    // ── подсказки ──
    W.QuestWin {
      id: foot
      pal: qp
      pad: 0
      y: head.height + 8 + frame.pageH + 8
      width: frame.width; height: 44
      transform: Scale { origin.y: foot.height / 2; yScale: w.g(3) }
      Row {
        anchors.centerIn: parent
        spacing: 30
        Repeater {
          model: w.pickList.opened ? ["↑↓ ВЫБОР", "ENTER ПРИНЯТЬ", "ESC ОТМЕНА"] : ["TAB ВКЛАДКА", "↑↓ СТРОКА", "←→ ЗНАЧЕНИЕ", "ENTER ДЕЙСТВИЕ", "ESC ВЫХОД"]
          Text { required property string modelData; text: modelData; color: qp.dim; font.family: qp.font(8); font.pixelSize: qp.size(8) }
        }
      }
    }
  }
  Connections { target: w; function onSearch() { page.search() } }
}

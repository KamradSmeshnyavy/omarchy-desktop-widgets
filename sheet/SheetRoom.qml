import QtQuick
import Quickshell
import ".." as W

// Панель настроек райса Cozy Room (Super+Alt+I): деревянная табличка «НАСТРОЙКИ КОМНАТЫ» сверху, слева — стойка
// с книгами-вкладками (корешок цветом книги, выбранная выдвинута вправо и подсвечена лампой), справа — большая записка
// (RoomNote), на ней страница (SkPage: тумблеры точками, шкалы клетками, выбор — списком) чернилами бумаги, снизу —
// подсказки клавиш карандашом. Мягко выплывает снизу. Клавиатура и выпадающий список — SkinWindow.
SkinWindow {
  id: w
  region: frame
  openMs: 380
  W.RoomPal { id: rp }
  readonly property int tabsW: 210

  Binding {
    target: Sk
    property: "t"
    value: ({ bg: "transparent", card: rp.alpha(rp.paperink, 0.05), ink: rp.paperink, dim: rp.alpha(rp.paperink, 0.6),
              accent: rp.mix(rp.lamp, rp.paperink, 0.25), onAccent: rp.paper, line: rp.alpha(rp.paperink, 0.3),
              sel: rp.alpha(rp.lamp, 0.25), font: rp.font, head: rp.font, size: 15, caps: false, spacing: 0, radius: 3,
              border: 1, shadow: 0, shadowColor: rp.ink, toggle: "dot", slider: "cells", title: "plain", chip: "box",
              popup: "list", swatch: "square", swap: "type", colW: 300, gap: 18, rowH: 32, labelW: 140,
              ring: rp.lamp, knobRadius: 0 })
  }

  Item {
    id: frame
    readonly property real pageH: Math.max(page.implicitHeight + 40, w.tabs.length * 32 + 30)
    width: Math.min(w.width - 40, Math.max(900, page.implicitWidth + w.tabsW + 80))
    height: 64 + 12 + pageH + 40
    x: Math.round((w.width - width) / 2)
    y: Math.round((w.height - height) / 2 + (1 - w.k) * 50)
    opacity: Math.min(1, w.k * 1.6)

    // ── табличка ──
    W.RoomWood {
      id: head
      pal: rp
      width: 420; height: 56
      anchors.horizontalCenter: parent.horizontalCenter
      radius: 6; plank: 0; pad: 0
      Text { anchors.centerIn: parent; text: "НАСТРОЙКИ КОМНАТЫ · " + SheetCore.title(w.tab).toLowerCase(); color: rp.onWood; font.family: rp.font; font.pixelSize: 19; font.bold: true }
    }

    // ── книги-вкладки ──
    W.RoomWood {
      id: shelf
      pal: rp
      y: 68
      width: w.tabsW; height: frame.pageH
      plank: 32; pad: 10
      Column {
        Repeater {
          model: w.tabs
          Item {
            id: tr
            required property string modelData
            required property int index
            readonly property bool on: w.tab === modelData
            width: w.tabsW - 26; height: 32
            Rectangle {
              x: tr.on ? 12 : 0
              width: parent.width - 12; height: 26
              anchors.verticalCenter: parent.verticalCenter
              color: rp.bookColors[tr.index % rp.bookColors.length]
              border.width: tr.on ? 2 : 1; border.color: tr.on ? rp.lamp : rp.ink
              antialiasing: false
              Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
              Text { x: 8; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 12; elide: Text.ElideRight; text: SheetCore.title(tr.modelData); color: rp.ink; font.family: rp.font; font.pixelSize: 14; font.bold: tr.on }
            }
            SkHit {
              anchors.fill: parent; kbdRadius: 0
              property int kbdOrder: 2000000 + tr.index
              readonly property string rowLabel: SheetCore.title(tr.modelData)
              readonly property string rowHint: "Enter — открыть · Tab / [ ] — соседняя"
              onHit: w.go(tr.modelData)
            }
          }
        }
      }
    }

    // ── записка со страницей ──
    W.RoomNote {
      id: noteWin
      pal: rp
      x: w.tabsW + 18; y: 72
      width: frame.width - x - 6; height: frame.pageH - 8
      tilt: 0.4
      pad: 16
      clip: false
      SkPage {
        id: page
        tab: w.tab
        dir: w.dir
        maxHeight: Math.min(560, w.height - 260)
      }
    }

    // ── подсказки ──
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      spacing: 26
      Repeater {
        model: w.pickList.opened ? ["↑↓ выбрать", "Enter — да", "Esc — отмена"] : ["Tab — книга", "↑↓ — строка", "←→ — значение", "Enter — сделать", "Esc — выйти"]
        Text { required property string modelData; text: modelData; color: rp.paper; style: Text.Outline; styleColor: rp.ink; font.family: rp.font; font.pixelSize: 15 }
      }
    }
  }
  Connections { target: w; function onSearch() { page.search() } }
}

import QtQuick
import qs.Commons as Commons

// Панель настроек Bruteon — «анкета на доске»: кремовый лист с толстым контуром на жёсткой тени, сверху — пастельные
// стикеры-закладки разделов (каждый чуть повёрнут, выбранный выше и без тени — «нажат»), разделы — пастельные наклейки,
// тумблеры — плитки ON / OFF, что падают на свою тень, шкалы — клетки с контуром. Лист падает сверху и, качнувшись,
// ложится ровно; разделы меняются сбросом сверху. JetBrains Mono жирным. Цвета — тема (бумага, чернила) и пастель Bruteon.
SkinWindow {
  id: w
  region: frame
  openMs: 520
  openEasing: Easing.OutBack
  readonly property color ink: Commons.Color.foreground
  readonly property color paper: Commons.Color.background
  readonly property bool dark: Sk.lum(paper) < 0.5
  readonly property color card: dark ? Sk.mix(paper, ink, 0.07) : Sk.mix(paper, "#ffffff", 0.35)
  readonly property color dk: dark ? "#000000" : "#161110"
  readonly property var pastels: ["#ffb77a", "#c5e1a5", "#ffcbd5", "#dcc4ec", "#90caf9", "#ffd98a", "#ffb3a1"]
  readonly property string mono: Sk.family("JetBrainsMono Nerd Font", "monospace")
  Binding {
    target: Sk
    property: "t"
    value: ({ bg: w.card, card: w.card, ink: w.ink, dim: Sk.alpha(w.ink, 0.65), accent: Commons.Color.accent, line: w.ink,
              sel: "#ffd98a", font: w.mono, head: w.mono, size: 12, caps: false, spacing: 0, radius: 8, border: 2,
              shadow: 4, shadowColor: w.dk, toggle: "square", slider: "cells", title: "sticker", chip: "fill", popup: "list",
              swatch: "block", swap: "drop", colW: 330, gap: 30, rowH: 28, labelW: 150, ring: w.ink, ringWidth: 3, pastels: w.pastels })
  }

  Item {
    id: frame
    width: Math.max(640, page.implicitWidth + 64, tabsRow.implicitWidth + 40)
    height: page.implicitHeight + 70 + tabsRow.height
    x: Math.round((w.width - width) / 2)
    y: Math.round((w.height - height) / 2 - (1 - w.k) * 120)
    opacity: Math.min(1, w.k * 3)
    rotation: (1 - w.k) * -4
    Behavior on width { NumberAnimation { duration: 200 } }
    Behavior on height { NumberAnimation { duration: 200 } }

    // лист
    Item {
      id: board
      y: tabsRow.height - 10
      width: parent.width - 8; height: parent.height - y - 8
      Rectangle { x: 8; y: 8; width: parent.width; height: parent.height; radius: 14; color: w.dk }
      Rectangle {
        anchors.fill: parent; radius: 14
        color: w.card
        border.width: 3; border.color: w.ink
        // скрепка
        Rectangle { x: parent.width - 70; y: -14; width: 18; height: 46; radius: 9; color: "transparent"; border.width: 3; border.color: Sk.alpha(w.ink, 0.6); rotation: 12 }
        Text { anchors.right: parent.right; anchors.rightMargin: 18; anchors.bottom: parent.bottom; anchors.bottomMargin: 10; text: "ESC · ?"; color: Sk.alpha(w.ink, 0.45); font.family: w.mono; font.pixelSize: 10; font.bold: true }
      }
      SkPage {
        id: page
        x: 28; y: 26
        tab: w.tab
        dir: w.dir
        maxHeight: Math.min(560, w.height - 260)
      }
    }
    // стикеры-закладки
    Flow {
      id: tabsRow
      x: 18
      width: frame.width - 36
      spacing: 6
      Repeater {
        model: w.tabs
        Item {
          id: st
          required property string modelData
          required property int index
          readonly property bool on: w.tab === modelData
          width: lb.implicitWidth + 22; height: 34
          rotation: on ? 0 : [-3, 2, -1.5, 3, -2, 1][index % 6]
          Rectangle { x: 4; y: 4; width: parent.width; height: 26; radius: 7; color: w.dk; visible: !st.on }
          Rectangle {
            x: st.on ? 4 : 0; y: st.on ? 4 : 0
            width: parent.width; height: 26; radius: 7
            color: w.pastels[st.index % w.pastels.length]
            border.width: 2.5; border.color: w.dk
            Behavior on x { NumberAnimation { duration: 90 } }
            Behavior on y { NumberAnimation { duration: 90 } }
            Text { id: lb; anchors.centerIn: parent; text: SheetCore.title(st.modelData).toUpperCase(); color: "#161110"; font.family: w.mono; font.pixelSize: 10; font.bold: true }
          }
          SkHit { anchors.fill: parent; kbdRadius: 7; property int kbdOrder: 2000000 + st.index; readonly property string rowLabel: st.modelData; onHit: w.go(st.modelData) }
        }
      }
    }
  }
  Connections { target: w; function onSearch() { page.search() } }
}

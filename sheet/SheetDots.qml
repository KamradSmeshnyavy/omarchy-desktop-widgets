import QtQuick
import "../dotmatrix" as DotMatrix

// Панель настроек DOT-MATRIX — «сервисное меню прибора»: чёрная панель с тонкими линиями, сверху — точечный дисплей
// с именем раздела (DotMatrix Dot, пиксели загораются при смене), под ним — ряд кнопок разделов со светодиодом
// (горит у выбранного), тумблеры — светодиод ON / OFF, шкалы — из точек, один красный сигнал. Цвета — только
// dotmatrix/Palette.qml. Панель «включается»: сначала рамка, потом загорается дисплей.
SkinWindow {
  id: w
  region: frame
  openMs: 360
  readonly property var pal: DotMatrix.Palette
  Binding {
    target: Sk
    property: "t"
    value: ({ bg: w.pal.bg, card: w.pal.surface, ink: w.pal.fg, dim: w.pal.dim, accent: w.pal.fg, onAccent: w.pal.bg,
              line: w.pal.line, sel: w.pal.fg, signal: w.pal.signal, unlit: w.pal.unlit, font: w.pal.fontMono, head: w.pal.fontMono,
              dotFont: w.pal.fontDot, size: 11, caps: true, spacing: 1.4, radius: 2, border: 1, shadow: 0, toggle: "led",
              slider: "dots", title: "dots", chip: "underline", popup: "list", swatch: "round", swap: "fade",
              colW: 330, gap: 30, rowH: 26, labelW: 150, ring: w.pal.signal, ringWidth: 1.5 })
  }

  Item {
    id: frame
    width: Math.max(700, page.implicitWidth + 60, tabKeys.implicitWidth + 40)
    height: page.implicitHeight + 190 + tabKeys.height
    x: Math.round((w.width - width) / 2)
    y: Math.round((w.height - height) / 2)
    opacity: Math.min(1, w.k * 3)
    Behavior on width { NumberAnimation { duration: 180 } }
    Behavior on height { NumberAnimation { duration: 180 } }

    Rectangle {
      anchors.fill: parent
      radius: 18
      color: w.pal.bg
      border.width: 1; border.color: w.pal.line
    }
    // винты по углам
    Repeater {
      model: [[12, 12], [frame.width - 20, 12], [12, frame.height - 20], [frame.width - 20, frame.height - 20]]
      Rectangle { required property var modelData; x: modelData[0]; y: modelData[1]; width: 8; height: 8; radius: 4; color: "transparent"; border.width: 1; border.color: w.pal.muted
        Rectangle { anchors.centerIn: parent; width: 5; height: 1; color: w.pal.muted; rotation: 45 } }
    }
    // точечный дисплей
    Rectangle {
      id: disp
      x: 30; y: 26
      width: frame.width - 60; height: 74
      radius: 8
      color: w.pal.surface
      border.width: 1; border.color: w.pal.lineSoft
      // фон точек
      Grid {
        x: 8; y: 6; columns: Math.floor((disp.width - 16) / 8); spacing: 0
        Repeater { model: Math.floor((disp.width - 16) / 8) * 8; Item { width: 8; height: 8; Rectangle { anchors.centerIn: parent; width: 2; height: 2; radius: 1; color: w.pal.unlit } } }
      }
      Text {
        x: 20; anchors.verticalCenter: parent.verticalCenter
        text: SheetCore.title(w.tab).toUpperCase()
        color: w.pal.fg
        opacity: Math.max(0, (w.k - 0.6) * 2.5)
        font.family: w.pal.fontDot; font.pixelSize: 40; font.letterSpacing: 3
      }
      Column {
        anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Text { anchors.right: parent.right; text: "SETTINGS · " + String(w.tabs.indexOf(w.tab) + 1).padStart(2, "0") + "/" + String(w.tabs.length).padStart(2, "0"); color: w.pal.dim; font.family: w.pal.fontMono; font.pixelSize: 10; font.letterSpacing: 1.6 }
        Row { anchors.right: parent.right; spacing: 6
          Text { text: "ESC  ?"; color: w.pal.muted; font.family: w.pal.fontMono; font.pixelSize: 10; font.letterSpacing: 1.6 }
          Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 7; height: 7; radius: 3.5; color: w.pal.signal } }
      }
    }
    // кнопки разделов
    Flow {
      id: tabKeys
      x: 30; y: disp.y + disp.height + 14
      width: frame.width - 60
      spacing: 6
      Repeater {
        model: w.tabs
        Rectangle {
          id: kb
          required property string modelData
          required property int index
          readonly property bool on: w.tab === modelData
          width: kl.implicitWidth + 30; height: 26
          radius: 13
          color: kh.containsMouse ? w.pal.surfaceHi : "transparent"
          border.width: 1; border.color: kb.on ? w.pal.fg : w.pal.line
          Rectangle { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 5; height: 5; radius: 2.5; color: kb.on ? w.pal.signal : w.pal.unlit }
          Text { id: kl; x: 20; anchors.verticalCenter: parent.verticalCenter; text: SheetCore.title(kb.modelData).toUpperCase(); color: kb.on ? w.pal.fg : w.pal.dim; font.family: w.pal.fontMono; font.pixelSize: 10; font.letterSpacing: 1.4 }
          SkHit { id: kh; anchors.fill: parent; kbdRadius: 13; property int kbdOrder: 2000000 + kb.index; readonly property string rowLabel: kb.modelData; onHit: w.go(kb.modelData) }
        }
      }
    }
    Rectangle { x: 30; y: tabKeys.y + tabKeys.height + 12; width: frame.width - 60; height: 1; color: w.pal.lineSoft }
    SkPage {
      id: page
      x: 30; y: tabKeys.y + tabKeys.height + 26
      tab: w.tab
      dir: w.dir
      maxHeight: Math.min(520, w.height - 320)
    }
  }
  Connections { target: w; function onSearch() { page.search() } }
}

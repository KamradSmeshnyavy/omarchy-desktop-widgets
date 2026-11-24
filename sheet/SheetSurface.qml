import QtQuick
import Quickshell
import qs.Commons as Commons

// Панель настроек surface — «колонка hub»: колонка у правого края (как его hub в Super+M), на главной — шапка
// с именем и плитки разделов в две колонки; выбранная плитка уводит в раздел сдвигом влево, сверху — крошка
// «‹ раздел» (Esc / Backspace / клик — назад на главную). Карточки — тон фона, акцент — заливка выбранного.
// Manrope (если есть), мягкие скругления. Выезжает справа.
SkinWindow {
  id: w
  region: frame
  openMs: 360
  property bool inside: false
  back: function() { if (w.inside) { w.inside = false; return true } return false }
  readonly property color fg: Commons.Color.foreground
  readonly property color bg: Commons.Color.background
  readonly property color acc: Commons.Color.accent
  readonly property bool dark: Sk.lum(bg) < 0.5
  readonly property color cardC: dark ? Sk.mix(bg, fg, 0.06) : Sk.mix(bg, "#000000", 0.055)
  readonly property color itemC: dark ? Sk.mix(bg, fg, 0.14) : Qt.rgba(0, 0, 0, 0.05)
  readonly property string font: Sk.family("Manrope", Commons.Style && Commons.Style.font ? Commons.Style.font.family : "sans-serif")
  readonly property string icons: Sk.family("JetBrainsMono Nerd Font", "monospace")
  readonly property real colW: 360
  Binding {
    target: Sk
    property: "t"
    value: ({ bg: w.cardC, card: w.itemC, ink: w.fg, dim: Sk.mix(w.fg, w.bg, 0.38), accent: w.acc, onAccent: Sk.ink(w.acc),
              line: Sk.alpha(w.fg, 0.2), sel: w.acc, font: w.font, head: w.font, size: 12, caps: false, spacing: 0, radius: 12,
              border: 0, shadow: 0, toggle: "pill", slider: "line", knobRadius: 5, title: "plain", chip: "fill", popup: "list",
              swatch: "round", swap: "fade", colW: w.colW - 36, gap: 18, rowH: 30, labelW: 130, ring: w.acc })
  }
  // Tab / [ ] / цифры с главной уводят в раздел (но не начальная вкладка при открытии)
  onTabChanged: if (w.k > 0.5 && !w.inside) w.inside = true

  Item {
    id: frame
    width: w.colW
    height: Math.min(w.height - 80, (w.inside ? inner.height : home.height) + 40)
    x: w.width - width - 14 + (1 - w.k) * (width + 20)
    y: 54
    Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    Rectangle { anchors.fill: parent; radius: 22; color: w.bg; border.width: 1; border.color: Sk.alpha(w.fg, 0.1) }
    Item {
      anchors.fill: parent
      clip: true
      // главная: шапка и плитки
      Column {
        id: home
        x: 18 - (w.inside ? w.colW : 0); y: 18
        width: w.colW - 36
        spacing: 12
        opacity: w.inside ? 0 : 1
        enabled: !w.inside
        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Row {
          spacing: 10
          Rectangle { width: 38; height: 38; radius: 19; color: w.itemC
            Text { anchors.centerIn: parent; text: "\u{F0493}"; color: w.acc; font.family: w.icons; font.pixelSize: 18 } }
          Column {
            anchors.verticalCenter: parent.verticalCenter
            Text { text: "Settings"; color: w.fg; font.family: w.font; font.pixelSize: 15; font.weight: 800 }
            Text { text: SheetCore.riceNow + " · " + (SheetCore.theme || ""); color: Sk.mix(w.fg, w.bg, 0.38); font.family: w.font; font.pixelSize: 10 }
          }
        }
        Grid {
          columns: 2
          columnSpacing: 8; rowSpacing: 8
          Repeater {
            model: w.tabs
            Rectangle {
              id: tile
              required property string modelData
              required property int index
              readonly property bool on: w.tab === modelData
              width: (w.colW - 44) / 2; height: 54
              radius: 14
              color: tile.on ? w.acc : tm.containsMouse ? Sk.mix(w.itemC, w.fg, 0.06) : w.itemC
              Behavior on color { ColorAnimation { duration: 140 } }
              Row {
                x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                Text { anchors.verticalCenter: parent.verticalCenter; text: SheetCore.icon(tile.modelData); color: tile.on ? Sk.ink(w.acc) : w.acc; font.family: w.icons; font.pixelSize: 17 }
                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  Text { text: SheetCore.title(tile.modelData); color: tile.on ? Sk.ink(w.acc) : w.fg; font.family: w.font; font.pixelSize: 12; font.weight: 700 }
                  Text { text: tile.index < 9 ? String(tile.index + 1) : ""; color: tile.on ? Sk.alpha(Sk.ink(w.acc), 0.7) : Sk.mix(w.fg, w.bg, 0.45); font.family: w.font; font.pixelSize: 9 }
                }
              }
              SkHit {
                id: tm
                anchors.fill: parent
                kbdRadius: 14
                readonly property string rowLabel: tile.modelData
                onHit: { if (w.tab === tile.modelData) w.inside = true; else w.go(tile.modelData) }
              }
            }
          }
        }
      }
      // раздел
      Column {
        id: inner
        x: 18 + (w.inside ? 0 : w.colW); y: 14
        width: w.colW - 36
        spacing: 10
        visible: w.inside || x < w.colW
        opacity: w.inside ? 1 : 0
        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Item {
          width: parent.width; height: 32
          Rectangle { anchors.fill: parent; radius: 16; color: bm.containsMouse ? Sk.mix(w.itemC, w.fg, 0.06) : w.itemC }
          Text { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "‹  " + SheetCore.title(w.tab); color: w.fg; font.family: w.font; font.pixelSize: 13; font.weight: 700 }
          Text { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: (w.tabs.indexOf(w.tab) + 1) + "/" + w.tabs.length; color: Sk.mix(w.fg, w.bg, 0.45); font.family: w.font; font.pixelSize: 10 }
          SkHit { id: bm; anchors.fill: parent; enabled: w.inside; kbdRadius: 16; property int kbdOrder: 0; onHit: w.inside = false }
        }
        SkPage {
          id: page
          enabled: w.inside
          tab: w.tab
          dir: w.dir
          oneColumn: true
          maxHeight: w.height - 200
        }
      }
    }
  }
  Connections { target: w; function onSearch() { w.inside = true; page.search() } }
}

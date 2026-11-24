import QtQuick
import QtQuick.Shapes
import qs.Commons as Commons

// Панель настроек Cozytile — «папка с язычками»: сверху ряд язычков с S-образными боками (как вкладки его бара),
// активный светится цветом выбора (magenta темы) и переходит в тёмную карточку цвета фона без шва; при смене раздела
// карточка перелистывается вбок. Колесо по язычкам и [ / ] листают разделы. JetBrains Mono.
SkinWindow {
  id: w
  region: frame
  openMs: 380
  readonly property color fg: Commons.Color.foreground
  readonly property color bg: Commons.Color.background
  readonly property color sel: Commons.Color.accent
  readonly property color cardC: Sk.mix(bg, fg, 0.05)
  readonly property string mono: Sk.family("JetBrainsMono Nerd Font", "monospace")
  Binding {
    target: Sk
    property: "t"
    value: ({ bg: w.cardC, card: Sk.mix(w.bg, w.fg, 0.09), ink: w.fg, dim: Sk.alpha(w.fg, 0.55), accent: w.sel, line: Sk.alpha(w.fg, 0.3),
              sel: w.sel, font: w.mono, head: w.mono, size: 12, caps: false, spacing: 0, radius: 10, border: 1, shadow: 0,
              toggle: "pill", slider: "bar", title: "rule", chip: "fill", popup: "list", swatch: "round", swap: "slide",
              colW: 320, gap: 28, rowH: 26, labelW: 150, ring: w.sel })
  }

  readonly property int tabH: 30
  Item {
    id: frame
    width: Math.max(640, page.implicitWidth + 56, tabRow.implicitWidth + 30)
    height: page.implicitHeight + 70 + w.tabH
    x: Math.round((w.width - width) / 2)
    y: Math.round((w.height - height) / 2 + (1 - w.k) * 40)
    opacity: Math.min(1, w.k * 2.5)
    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    // карточка
    Rectangle {
      id: card
      y: w.tabH
      width: parent.width; height: parent.height - w.tabH
      radius: 14
      color: w.cardC
      border.width: 1; border.color: Sk.alpha(w.sel, 0.45)
      Text { anchors.right: parent.right; anchors.rightMargin: 16; anchors.bottom: parent.bottom; anchors.bottomMargin: 8; text: "[ ]  tab  esc  ?"; color: Sk.alpha(w.fg, 0.35); font.family: w.mono; font.pixelSize: 10 }
      Item {
        x: 26; y: 24
        width: parent.width - 40; height: parent.height - 40
        clip: true
        SkPage {
          id: page
          tab: w.tab
          dir: w.dir
          maxHeight: Math.min(560, w.height - 240)
        }
      }
    }
    // язычки
    Row {
      id: tabRow
      x: 14
      spacing: -10
      Repeater {
        model: w.tabs
        Item {
          id: tb
          required property string modelData
          required property int index
          readonly property bool on: w.tab === modelData
          z: on ? 10 : -index
          width: tl.implicitWidth + 44; height: w.tabH + (on ? 2 : 0)
          y: on ? 0 : 4
          Behavior on y { NumberAnimation { duration: 140 } }
          // S-образные бока: снизу расходятся наружу, к карточке
          Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
              fillColor: tb.on ? w.cardC : Sk.mix(w.bg, w.fg, th.containsMouse ? 0.1 : 0.03)
              strokeColor: tb.on ? Sk.alpha(w.sel, 0.45) : Sk.alpha(w.fg, 0.18)
              strokeWidth: 1
              startX: 0; startY: tb.height
              PathCubic { x: 18; y: 0; control1X: 10; control1Y: tb.height; control2X: 8; control2Y: 0 }
              PathLine { x: tb.width - 18; y: 0 }
              PathCubic { x: tb.width; y: tb.height; control1X: tb.width - 8; control1Y: 0; control2X: tb.width - 10; control2Y: tb.height }
            }
          }
          Rectangle { visible: tb.on; x: 20; width: parent.width - 40; height: 2; y: 1; radius: 1; color: w.sel }
          Text {
            id: tl
            anchors.centerIn: parent
            text: SheetCore.title(tb.modelData).toLowerCase()
            color: tb.on ? w.sel : Sk.alpha(w.fg, 0.6)
            font.family: w.mono; font.pixelSize: 11; font.bold: tb.on
          }
          SkHit {
            id: th
            anchors.fill: parent
            kbdRadius: 8
            property int kbdOrder: 2000000 + tb.index
            readonly property string rowLabel: tb.modelData
            onHit: w.go(tb.modelData)
            onWheel: e => w.step(e.angleDelta.y < 0 ? 1 : -1)
          }
        }
      }
    }
  }
  Connections { target: w; function onSearch() { page.search() } }
}

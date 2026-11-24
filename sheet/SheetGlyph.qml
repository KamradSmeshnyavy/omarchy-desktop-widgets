import QtQuick
import qs.Commons as Commons

// Панель настроек Glyph — «настройки Nothing OS»: монохромная карточка, крупный точечный заголовок раздела слева
// вверху, разделы — точечные капсулы в ряд (выбранная залита), списки с тонкими разделителями, переключатели —
// круг с красной точкой, шкалы — из точек; красный — только сигнал (акцент темы Glyph). Space Grotesk + точечный
// шрифт. Карточка поднимается снизу, заголовок «набирается» точками.
SkinWindow {
  id: w
  region: frame
  openMs: 400
  readonly property color fg: Commons.Color.foreground
  readonly property color bg: Commons.Color.background
  readonly property color red: Commons.Color.accent
  readonly property bool dark: Sk.lum(bg) < 0.5
  readonly property color cardC: dark ? Sk.mix(bg, fg, 0.04) : Sk.mix(bg, "#ffffff", 0.5)
  readonly property string grotesk: Sk.family("Space Grotesk", Commons.Style && Commons.Style.font ? Commons.Style.font.family : "sans-serif")
  readonly property string dot: Sk.family("DotMatrix Dot", Sk.family("Doto", w.grotesk))
  readonly property string mono: Sk.family("Space Mono", Sk.family("JetBrainsMono Nerd Font", "monospace"))
  Binding {
    target: Sk
    property: "t"
    value: ({ bg: w.cardC, card: Sk.mix(w.cardC, w.fg, 0.05), ink: w.fg, dim: Sk.alpha(w.fg, 0.55), accent: w.fg, onAccent: w.bg,
              line: Sk.alpha(w.fg, 0.16), sel: w.fg, signal: w.red, unlit: Sk.alpha(w.fg, 0.14), font: w.grotesk, head: w.mono,
              dotFont: w.dot, size: 13, caps: false, spacing: 0, radius: 16, border: 1, shadow: 0, toggle: "dot",
              slider: "dots", title: "plain", chip: "invert", popup: "list", swatch: "round", swap: "slide",
              colW: 330, gap: 30, rowH: 30, labelW: 150, ring: w.red, ringWidth: 1.5 })
  }

  Item {
    id: frame
    width: Math.max(680, page.implicitWidth + 64, caps.implicitWidth + 48)
    height: page.implicitHeight + 150 + caps.height
    x: Math.round((w.width - width) / 2)
    y: Math.round((w.height - height) / 2 + (1 - w.k) * 60)
    opacity: Math.min(1, w.k * 2.5)
    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    Rectangle { anchors.fill: parent; radius: 28; color: w.cardC; border.width: 1; border.color: Sk.alpha(w.fg, 0.12) }
    // заголовок точками: буквы проявляются по одной
    Text {
      id: head
      x: 32; y: 22
      readonly property string full: SheetCore.title(w.tab)
      property int shown: full.length
      text: full.slice(0, shown)
      color: w.fg
      font.family: w.dot; font.pixelSize: 42
      onFullChanged: { shown = 0; typer.restart() }
      Timer { id: typer; interval: 35; repeat: true; running: false; onTriggered: { head.shown++; if (head.shown >= head.full.length) stop() } }
    }
    Rectangle { x: head.x + head.implicitWidth + 8; y: head.y + 30; width: 8; height: 8; radius: 4; color: w.red }
    Text { anchors.right: parent.right; anchors.rightMargin: 32; y: 38; text: "SETTINGS  ·  ESC  ·  ?"; color: Sk.alpha(w.fg, 0.4); font.family: w.mono; font.pixelSize: 10; font.letterSpacing: 1.4 }
    // капсулы разделов
    Flow {
      id: caps
      x: 32; y: 86
      width: frame.width - 64
      spacing: 6
      Repeater {
        model: w.tabs
        Rectangle {
          id: cp
          required property string modelData
          required property int index
          readonly property bool on: w.tab === modelData
          width: cl.implicitWidth + 24; height: 28; radius: 14
          color: cp.on ? w.fg : ch.containsMouse ? Sk.alpha(w.fg, 0.08) : "transparent"
          border.width: 1; border.color: cp.on ? w.fg : Sk.alpha(w.fg, 0.25)
          Behavior on color { ColorAnimation { duration: 140 } }
          Text { id: cl; anchors.centerIn: parent; text: SheetCore.title(cp.modelData).toUpperCase(); color: cp.on ? w.bg : Sk.alpha(w.fg, 0.75); font.family: w.mono; font.pixelSize: 10; font.letterSpacing: 1.2 }
          SkHit { id: ch; anchors.fill: parent; kbdRadius: 14; property int kbdOrder: 2000000 + cp.index; readonly property string rowLabel: cp.modelData; onHit: w.go(cp.modelData) }
        }
      }
    }
    SkPage {
      id: page
      x: 32; y: caps.y + caps.height + 22
      tab: w.tab
      dir: w.dir
      maxHeight: Math.min(540, w.height - 300)
    }
  }
  Connections { target: w; function onSearch() { page.search() } }
}

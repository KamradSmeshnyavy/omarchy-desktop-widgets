import QtQuick
import qs.Commons as Commons

// Панель настроек Unit-3 — «системное меню YoRHa» (NieR:Automata): бежевое поле в мелкую сетку, сверху крупное
// «SYSTEM» и подпись раздела; слева — разделы полосами с квадратным маркером (выбранный — тёмная полоса, рядом
// мигающий указатель), в центре — настройки, справа — рамка «Описание» строки под курсором (что это, значение,
// клавиши). Открывается «проявлением» от горизонтальной линии, как меню NieR. Цвета — тема Unit-3 (бумага, чернила).
SkinWindow {
  id: w
  region: frame
  openMs: 420
  readonly property color paper: Commons.Color.background
  readonly property color ink: Commons.Color.foreground
  readonly property color acc: Commons.Color.accent
  readonly property color soft: Sk.mix(paper, ink, 0.12)
  readonly property string sans: Sk.family("Inter", Commons.Style && Commons.Style.font ? Commons.Style.font.family : "sans-serif")
  readonly property string mono: Sk.family("Iosevka", Sk.family("JetBrainsMono Nerd Font", "monospace"))
  property bool blink: true
  Timer { interval: 600; running: true; repeat: true; onTriggered: w.blink = !w.blink }
  Binding {
    target: Sk
    property: "t"
    value: ({ bg: w.paper, card: w.soft, ink: w.ink, dim: Sk.alpha(w.ink, 0.62), accent: w.ink, onAccent: w.paper, line: w.ink,
              sel: w.ink, font: w.sans, head: w.sans, size: 12, caps: false, spacing: 0.6, radius: 0, border: 1, shadow: 0,
              toggle: "stripe", slider: "line", knobRadius: 0, title: "stripe", chip: "invert", popup: "list", swatch: "square",
              swap: "fade", colW: 320, gap: 24, rowH: 28, labelW: 150, ring: w.ink })
  }
  // строка под курсором (KeyNav) или под мышью — для «Описания»
  function rowOf(it) { for (let p = it; p; p = p.parent) if (p.rowLabel !== undefined) return p; return null }
  readonly property var row: w.nav.current ? rowOf(w.nav.host(w.nav.current)) : null

  Item {
    id: frame
    readonly property real fullH: Math.max(page.implicitHeight, w.tabs.length * 32) + 150
    width: Math.min(w.width - 60, page.implicitWidth + 200 + 290)
    height: fullH
    x: Math.round((w.width - width) / 2)
    y: Math.round((w.height - fullH) / 2)
    Behavior on width { NumberAnimation { duration: 200 } }

    // проявление от линии
    Rectangle {
      id: field
      width: parent.width
      height: parent.height * Math.min(1, w.k * 1.25)
      y: (parent.height - height) / 2
      color: w.paper
      clip: true
      // сетка
      Repeater { model: Math.ceil(frame.width / 24); Rectangle { required property int index; x: index * 24; width: 1; height: field.height; color: Sk.alpha(w.ink, 0.05) } }
      Repeater { model: Math.ceil(frame.height / 24); Rectangle { required property int index; y: index * 24; height: 1; width: field.width; color: Sk.alpha(w.ink, 0.05) } }
      Item {
        width: frame.width; height: frame.height
        y: -(frame.height - field.height) / 2
        opacity: Math.max(0, (w.k - 0.5) * 2)
        Text { x: 30; y: 20; text: "SYSTEM"; color: w.ink; font.family: w.sans; font.pixelSize: 30; font.weight: Font.Light; font.letterSpacing: 6 }
        Text { x: 34; y: 60; text: SheetCore.title(w.tab).toUpperCase() + "  /  YoRHa  Unit-3"; color: Sk.alpha(w.ink, 0.6); font.family: w.mono; font.pixelSize: 10; font.letterSpacing: 2 }
        Rectangle { x: 30; y: 84; width: frame.width - 60; height: 1; color: Sk.alpha(w.ink, 0.5) }
        Row { x: 30; y: 88; spacing: 4; Repeater { model: Math.floor((frame.width - 60) / 10); Rectangle { width: 6; height: 2; color: Sk.alpha(w.ink, 0.25) } } }

        // разделы
        Column {
          id: tabCol
          x: 30; y: 104
          spacing: 4
          Repeater {
            model: w.tabs
            Item {
              id: tr
              required property string modelData
              required property int index
              readonly property bool on: w.tab === modelData
              width: 170; height: 28
              Rectangle { anchors.fill: parent; color: tr.on ? w.ink : th.containsMouse ? Sk.alpha(w.ink, 0.12) : Sk.alpha(w.ink, 0.06) }
              Rectangle { x: 8; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; color: tr.on ? w.paper : w.ink }
              Text { x: 24; anchors.verticalCenter: parent.verticalCenter; text: SheetCore.title(tr.modelData); color: tr.on ? w.paper : w.ink; font.family: w.sans; font.pixelSize: 12; font.letterSpacing: 0.8 }
              Text { visible: tr.on && w.blink; x: -18; anchors.verticalCenter: parent.verticalCenter; text: "▶"; color: w.ink; font.pixelSize: 11 }
              SkHit { id: th; anchors.fill: parent; kbdRadius: 0; property int kbdOrder: 2000000 + tr.index; readonly property string rowLabel: SheetCore.title(tr.modelData); readonly property string rowHint: "Enter — open · Tab / [ ] — next"; onHit: w.go(tr.modelData) }
            }
          }
        }
        SkPage {
          id: page
          x: 230; y: 106
          tab: w.tab
          dir: w.dir
          maxHeight: Math.min(560, w.height - 260)
        }
        // «Описание»
        Rectangle {
          x: frame.width - 270; y: 106
          width: 240; height: Math.min(260, frame.height - 150)
          color: Sk.alpha(w.ink, 0.06)
          border.width: 1; border.color: Sk.alpha(w.ink, 0.5)
          Rectangle { width: parent.width; height: 24; color: w.ink
            Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: "Description"; color: w.paper; font.family: w.sans; font.pixelSize: 11; font.letterSpacing: 1.5 } }
          Column {
            x: 12; y: 36; width: parent.width - 24; spacing: 10
            Text { width: parent.width; wrapMode: Text.Wrap; text: w.row ? String(w.row.rowLabel) : SheetCore.title(w.tab); color: w.ink; font.family: w.sans; font.pixelSize: 14 }
            Rectangle { width: parent.width; height: 1; color: Sk.alpha(w.ink, 0.3) }
            Text { visible: !!(w.row && w.row.rowValue); width: parent.width; wrapMode: Text.Wrap; text: w.row && w.row.rowValue ? "Current: " + w.row.rowValue : ""; color: w.ink; font.family: w.mono; font.pixelSize: 11 }
            Text { width: parent.width; wrapMode: Text.Wrap; text: w.row && w.row.rowHint ? w.row.rowHint : "↑ ↓ ← → move · Enter select · Tab next section · ? keys · Esc close"; color: Sk.alpha(w.ink, 0.65); font.family: w.mono; font.pixelSize: 10; lineHeight: 1.3 }
          }
        }
      }
    }
    // линия «проявления»
    Rectangle { y: parent.height / 2; width: parent.width * Math.min(1, w.k * 3); height: 1; color: w.ink; visible: w.k < 0.95 }
  }
  Connections { target: w; function onSearch() { page.search() } }
}

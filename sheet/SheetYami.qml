import QtQuick
import Quickshell
import qs.Commons as Commons

// Панель настроек yami — «settings.conf в терминале»: окно консоли с рамкой в пиксель и жёсткой тенью 3 px,
// шапка «yami@host:~$ nvim settings.conf», под ней — буферы «[1:core] 2:colors …» (выбранный — инверсией), строки
// «ключ = значение», тумблеры [x], шкалы ██████▒▒▒, выбор — всплывашкой автодополнения, внизу — строка статуса vim
// (-- NORMAL --, файл, номер буфера). Окно «раскрывается» из строки заголовка; страница печатается сверху вниз.
// Tiny5 — заголовки и статус, один акцент темы.
SkinWindow {
  id: w
  region: frame
  openMs: 300
  readonly property color fg: Commons.Color.foreground
  readonly property color bg: Commons.Color.background
  readonly property color acc: Commons.Color.accent
  readonly property color panel: Qt.rgba(bg.r * 0.85, bg.g * 0.85, bg.b * 0.85, 1)
  readonly property string px: Sk.family("Tiny5", "monospace")
  readonly property string mono: Sk.family("JetBrainsMono Nerd Font", "monospace")
  readonly property string host_: Quickshell.env("HOSTNAME") || "yami"
  property bool blink: true
  Timer { interval: 530; running: true; repeat: true; onTriggered: w.blink = !w.blink }
  Binding {
    target: Sk
    property: "t"
    value: ({ bg: w.panel, card: w.bg, ink: w.fg, dim: Sk.alpha(w.fg, 0.55), accent: w.acc, onAccent: w.bg, line: w.fg,
              sel: w.acc, font: w.mono, head: w.px, size: 12, caps: false, spacing: 0, radius: 0, border: 2, shadow: 3,
              shadowColor: Qt.darker(w.acc, 2.2), toggle: "check", slider: "blocks", title: "comment", chip: "bracket",
              popup: "completion", swatch: "square", swap: "type", colW: 330, gap: 28, rowH: 24, labelW: 160, ring: w.acc, knobRadius: 0 })
  }

  Item {
    id: frame
    readonly property real fullH: page.implicitHeight + 128
    width: Math.max(620, page.implicitWidth + 48)
    height: Math.round(30 + (fullH - 30) * Math.min(1, w.k))
    x: Math.round((w.width - width) / 2)
    y: Math.round((w.height - fullH) / 2)
    opacity: Math.min(1, w.k * 4)
    Behavior on width { NumberAnimation { duration: 160 } }

    Rectangle { x: 3; y: 3; width: parent.width; height: parent.height; color: Qt.darker(w.acc, 2.2) }
    Rectangle {
      anchors.fill: parent
      color: w.panel
      border.width: 2; border.color: w.fg
      clip: true
      // шапка
      Rectangle {
        width: parent.width; height: 28
        color: w.fg
        Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: w.host_ + "@yami:~$ nvim settings.conf"; color: w.panel; font.family: w.px; font.pixelSize: 12 }
        Row {
          anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 6
          Repeater { model: 3; Rectangle { width: 9; height: 9; color: index === 2 ? w.acc : w.panel } }
        }
      }
      // буферы
      Flow {
        id: bufs
        x: 10; y: 34
        width: parent.width - 20
        spacing: 2
        Repeater {
          model: w.tabs
          Item {
            id: b
            required property string modelData
            required property int index
            readonly property bool on: w.tab === modelData
            width: bt.implicitWidth + 10; height: 18
            Rectangle { anchors.fill: parent; color: b.on ? w.acc : bh.containsMouse ? Sk.alpha(w.fg, 0.12) : "transparent" }
            Text { id: bt; anchors.centerIn: parent; text: (b.index < 9 ? (b.index + 1) + ":" : "") + b.modelData; color: b.on ? w.panel : Sk.alpha(w.fg, 0.7); font.family: w.px; font.pixelSize: 11 }
            SkHit { id: bh; anchors.fill: parent; kbdRadius: 0; property int kbdOrder: 2000000 + b.index; readonly property string rowLabel: b.modelData; onHit: w.go(b.modelData) }
          }
        }
      }
      Rectangle { x: 10; y: bufs.y + bufs.height + 4; width: parent.width - 20; height: 1; color: Sk.alpha(w.fg, 0.25) }
      // номера строк
      Column {
        x: 10; y: page.y
        Repeater {
          model: Math.ceil(page.height / 24)
          Text { required property int index; width: 22; height: 24; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter; text: index + 1; color: Sk.alpha(w.fg, 0.25); font.family: w.mono; font.pixelSize: 10 }
        }
      }
      SkPage {
        id: page
        x: 40; y: bufs.y + bufs.height + 12
        tab: w.tab
        dir: w.dir
        maxHeight: Math.min(560, w.height - 240)
      }
      // строка статуса
      Rectangle {
        anchors.bottom: parent.bottom; anchors.bottomMargin: 2
        x: 2; width: parent.width - 4; height: 22
        color: Sk.alpha(w.fg, 0.1)
        Row {
          x: 0; height: parent.height; spacing: 10
          Rectangle { height: parent.height; width: mode.implicitWidth + 14; color: w.acc
            Text { id: mode; anchors.centerIn: parent; text: w.pickList.opened ? "-- INSERT --" : "-- NORMAL --"; color: w.panel; font.family: w.px; font.pixelSize: 11 } }
          Text { anchors.verticalCenter: parent.verticalCenter; text: "settings.conf  [" + w.tab + "]"; color: w.fg; font.family: w.px; font.pixelSize: 11 }
        }
        Text {
          anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
          text: (w.tabs.indexOf(w.tab) + 1) + "/" + w.tabs.length + "   ?:help  :q esc" + (w.blink ? " ▌" : "  ")
          color: Sk.alpha(w.fg, 0.6); font.family: w.px; font.pixelSize: 11
        }
      }
    }
  }
  Connections { target: w; function onSearch() { page.search() } }
}

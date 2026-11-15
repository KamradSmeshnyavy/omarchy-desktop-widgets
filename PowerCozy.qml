import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Меню выключения Cozytile (powerStyle "cozytile", по мотивам rofi-меню Cozytile, Darkkal44 — лицензии нет, только облик,
// код свой): карточка 800 px на фоне текущих обоев (у него — power.png), слева сверху « Power», справа — аптайм; ниже —
// пять крупных значков (блокировка, сон, выход, перезагрузка, выключение), выбранный залит цветом выбора темы (magenta в
// colors.toml), значок на нём — цветом фона. Выход, перезагрузка и выключение спрашивают «Are you sure?» (Yes / No).
// ←→ Tab — выбор, Enter — выполнить, Esc и клик мимо — назад / закрыть. Открывается host.powerOpen.
PanelWindow {
  id: root

  required property var host
  readonly property bool open: host.powerOpen && host.value("powerStyle") === "cozytile"
  readonly property color bg: host.background
  readonly property color fg: host.foreground
  property color selected: host.accent
  readonly property string mono: Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : "monospace"

  readonly property var items: [
    { g: "\u{F033E}", cmd: "omarchy-system-lock", ask: false },
    { g: "\u{F0904}", cmd: "systemctl suspend", ask: false },
    { g: "\u{F0343}", cmd: "omarchy-system logout", ask: true },
    { g: "\u{F0709}", cmd: "omarchy-system reboot", ask: true },
    { g: "\u{F0425}", cmd: "omarchy-system shutdown", ask: true }
  ]
  property int sel: 0
  property bool asking: false
  property int yes: 0
  property string uptime: ""
  property real k: open ? 1 : 0
  Behavior on k { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

  Process {
    id: up
    command: ["uptime", "-p"]
    stdout: StdioCollector { onStreamFinished: root.uptime = String(text || "").trim().replace(/^up\s+/, "") }
  }
  Process {
    id: pal
    command: ["sh", "-c", "sed -n 's/^magenta = \"\\(#[0-9a-fA-F]*\\)\"/\\1/p' \"$HOME/.local/state/omarchy/current/theme/colors.toml\""]
    stdout: StdioCollector { onStreamFinished: { var c = String(text || "").trim(); if (c) root.selected = c } }
  }
  onOpenChanged: if (open) { sel = 0; asking = false; up.running = true; pal.running = true; card.forceActiveFocus() }
  function close() { host.powerOpen = false }
  function pick(i) {
    sel = i
    if (items[i].ask && !asking) { asking = true; yes = 0; return }
    var c = items[i].cmd
    close()
    Quickshell.execDetached(["bash", "-c", c])
  }

  screen: host.focusedScreen
  visible: open || k > 0.01
  anchors { left: true; right: true; top: true; bottom: true }
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  WlrLayershell.namespace: "omarchy-power"

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.35 * root.k)
    MouseArea { anchors.fill: parent; onClicked: { if (root.asking) root.asking = false; else root.close() } }
  }

  Rectangle {
    id: card
    width: 800; height: 300
    anchors.centerIn: parent
    opacity: root.k
    scale: 0.97 + 0.03 * root.k
    color: root.bg
    clip: true
    focus: true
    Keys.onPressed: e => {
      var act = e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space
      if (e.key === Qt.Key_Escape) { if (root.asking) root.asking = false; else root.close() }
      else if (root.asking) {
        if (e.key === Qt.Key_Left || e.key === Qt.Key_Right || e.key === Qt.Key_Tab) root.yes = 1 - root.yes
        else if (act) { if (root.yes === 1) root.pick(root.sel); else root.asking = false }
      }
      else if (e.key === Qt.Key_Left || e.key === Qt.Key_H) root.sel = (root.sel + 4) % 5
      else if (e.key === Qt.Key_Right || e.key === Qt.Key_L || e.key === Qt.Key_Tab) root.sel = (root.sel + 1) % 5
      else if (act) root.pick(root.sel)
      else return
      e.accepted = true
    }
    MouseArea { anchors.fill: parent }
    Image {
      anchors.fill: parent
      source: "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
      fillMode: Image.PreserveAspectCrop
      sourceSize.width: 1000
      asynchronous: true
      cache: false
    }
    Rectangle { anchors.fill: parent; color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.18) }

    Text { x: 14; y: 11; text: "\u{F0425}  Power"; color: root.fg; font { family: root.mono; pixelSize: 15; bold: true } }
    Text { anchors.right: parent.right; anchors.rightMargin: 14; y: 11; text: root.uptime ? "Uptime: " + root.uptime : ""; color: root.fg; font { family: root.mono; pixelSize: 15 } }

    Row {
      visible: !root.asking
      anchors.horizontalCenter: parent.horizontalCenter
      y: 120
      spacing: 15
      Repeater {
        model: root.items
        Rectangle {
          required property var modelData
          required property int index
          readonly property bool on: index === root.sel
          width: (800 - 30 - 60 - 4 * 15) / 5; height: 110
          radius: 10
          color: on ? root.selected : th.hovered ? Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.55) : Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.35)
          Behavior on color { ColorAnimation { duration: 120 } }
          Text { anchors.centerIn: parent; text: modelData.g; color: parent.on ? root.bg : root.fg; font { family: root.mono; pixelSize: 40 } }
          HoverHandler { id: th; cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) root.sel = index }
          TapHandler { onTapped: root.pick(index) }
        }
      }
    }
    Column {
      visible: root.asking
      anchors.horizontalCenter: parent.horizontalCenter
      y: 92
      spacing: 18
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: ask.implicitWidth + 30; height: 38; radius: 10
        color: Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.8)
        Text { id: ask; anchors.centerIn: parent; text: "Are you sure?"; color: root.fg; font { family: root.mono; pixelSize: 15; bold: true } }
      }
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 15
        Repeater {
          model: [{ g: "\u{F05E1}", v: 1 }, { g: "\u{F0156}", v: 0 }]
          Rectangle {
            required property var modelData
            readonly property bool on: root.yes === modelData.v
            width: 160; height: 90; radius: 10
            color: on ? root.selected : Qt.rgba(root.bg.r, root.bg.g, root.bg.b, 0.5)
            Text { anchors.centerIn: parent; text: modelData.g; color: parent.on ? root.bg : root.fg; font { family: root.mono; pixelSize: 36 } }
            HoverHandler { cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) root.yes = parent.modelData.v }
            TapHandler { onTapped: { if (parent.modelData.v === 1) root.pick(root.sel); else root.asking = false } }
          }
        }
      }
    }
  }
}

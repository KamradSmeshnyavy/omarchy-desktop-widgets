import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Меню выключения Cassini (powerStyle "cassini", по мотивам surface-dots, snes19xx — utils/Cassini.qml и
// PowerMenuController.qml; README разрешает брать со ссылкой; код свой). «Редакционная» чёрно-белая карточка 600 × 315:
// слева «@имя» крупным Newsreader, под ним «up 2 hours, 30 minutes» курсивом CMU Typewriter (числа прямые), ниже —
// список Lock / Suspend / Logout / Reboot / Shutdown; выбранная строка — сплошная плашка (зелёная, у Reboot и Shutdown —
// красная), под курсором — лёгкая заливка. Справа — случайный снимок Сатурна миссии Cassini (NASA / JPL-Caltech / Space
// Science Institute, общественное достояние; surface/cassini). Выбор — подтверждение «Lock Screen?» с No / Yes.
// ↑↓ ←→ Tab — по списку, Enter — выбрать, в подтверждении ←→ — No / Yes, Esc и клик мимо — назад / закрыть.
// Открывается тем же host.powerOpen (omarchy-shell widgets togglePower).
PanelWindow {
  id: root

  required property var host
  readonly property bool open: host.powerOpen && host.value("powerStyle") === "cassini"
  readonly property color bg0: host.background
  readonly property bool dark: 0.299 * bg0.r + 0.587 * bg0.g + 0.114 * bg0.b < 0.5

  readonly property color cardBg: dark ? "#0c0c0d" : "#fbfbf9"
  readonly property color ink: dark ? "#f2f2f0" : "#161616"
  readonly property color dim: dark ? "#8b8b88" : "#6c6c6a"
  readonly property color line: dark ? "#262628" : "#e3e3df"
  readonly property color selBg: dark ? Qt.rgba(0.498, 0.69, 0.412, 0.835) : "#759b61"
  readonly property color selFg: dark ? "#0c0c0d" : "#fbfbf9"
  readonly property color danger: dark ? "#e06c75" : "#c0392b"
  readonly property color confirm: dark ? "#7fb069" : "#2e7d32"
  readonly property string serif: Qt.fontFamilies().indexOf("Newsreader") !== -1 ? "Newsreader" : "serif"
  readonly property string mono: Qt.fontFamilies().indexOf("CMU Typewriter Text") !== -1 ? "CMU Typewriter Text" : "monospace"

  readonly property var items: [
    { label: "Lock", cmd: "omarchy-system-lock", key: "lock" },
    { label: "Suspend", cmd: "systemctl suspend", key: "suspend" },
    { label: "Logout", cmd: "omarchy-system logout", key: "logout" },
    { label: "Reboot", cmd: "omarchy-system reboot", key: "reboot" },
    { label: "Shutdown", cmd: "omarchy-system shutdown", key: "shutdown" }
  ]
  property int sel: 0
  property int pending: -1
  property int yes: 1
  property int plate: 1
  property string uptime: ""
  property real intro: 0
  Behavior on intro { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

  Process {
    id: up
    command: ["uptime", "-p"]
    stdout: StdioCollector { onStreamFinished: root.uptime = String(text || "").trim().replace(/^up\s+/, "") }
  }
  onOpenChanged: {
    if (open) { sel = 0; pending = -1; yes = 1; plate = Math.floor(Math.random() * 14) + 1; up.running = true; intro = 1; card.forceActiveFocus() }
    else intro = 0
  }
  function close() { host.powerOpen = false }
  function back() { if (pending >= 0) pending = -1; else close() }
  function ask(i) { sel = i; pending = i; yes = 1 }
  function run() {
    var c = items[pending].cmd
    close()
    Quickshell.execDetached(["bash", "-c", c])
  }
  function confirmText(k) {
    return ({ shutdown: "Power Off?", reboot: "Reboot System?", logout: "Log Out?", lock: "Lock Screen?", suspend: "Suspend?" })[k] || "Are you sure?"
  }

  screen: host.focusedScreen
  visible: open || intro > 0.01
  anchors { left: true; right: true; top: true; bottom: true }
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  WlrLayershell.namespace: "omarchy-power"

  Rectangle {
    anchors.fill: parent
    color: root.dark ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(0.914, 0.906, 0.906, 0.61)
    opacity: root.intro
    MouseArea { anchors.fill: parent; onClicked: root.back() }
  }

  Item {
    id: card
    width: 600; height: 315
    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2 + (1 - root.intro) * 24)
    opacity: root.intro
    focus: true
    Keys.onPressed: e => {
      var act = e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space
      if (e.key === Qt.Key_Escape) root.back()
      else if (root.pending >= 0) {
        if (e.key === Qt.Key_Left || e.key === Qt.Key_Right || e.key === Qt.Key_Tab) root.yes = 1 - root.yes
        else if (act) { if (root.yes === 1) root.run(); else root.pending = -1 }
      }
      else if (e.key === Qt.Key_Up || e.key === Qt.Key_Left || e.key === Qt.Key_K) root.sel = (root.sel + 4) % 5
      else if (e.key === Qt.Key_Down || e.key === Qt.Key_Right || e.key === Qt.Key_Tab || e.key === Qt.Key_J) root.sel = (root.sel + 1) % 5
      else if (act) root.ask(root.sel)
      else return
      e.accepted = true
    }

    // тень
    Rectangle { id: shadowSrc; anchors.fill: parent; radius: 9; color: root.cardBg; visible: false; layer.enabled: true }
    MultiEffect {
      anchors.fill: parent
      source: shadowSrc
      shadowEnabled: true
      shadowVerticalOffset: 8
      shadowBlur: 0.7
      shadowColor: root.dark ? "#aa000000" : "#55000000"
    }
    Item {
      id: body
      anchors.fill: parent
      visible: false
      layer.enabled: true
      Rectangle { anchors.fill: parent; color: root.cardBg }
      MouseArea { anchors.fill: parent }
      Image {
        id: photo
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        width: 315
        source: Qt.resolvedUrl("surface/cassini/" + root.plate + ".jpg")
        fillMode: Image.PreserveAspectCrop
        mipmap: true
        asynchronous: true
      }
      Rectangle { anchors { top: parent.top; bottom: parent.bottom; right: photo.left } width: 1; color: root.line }
    }
    Rectangle { id: mask; anchors.fill: parent; radius: 9; visible: false; layer.enabled: true }
    MultiEffect { anchors.fill: parent; source: body; maskEnabled: true; maskSource: mask; maskThresholdMin: 0.5 }

    Item {
      id: content
      anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
      width: parent.width - 315
      Column {
        id: head
        x: 27; y: 27
        width: content.width - 54
        spacing: 2
        Text { width: parent.width; elide: Text.ElideRight; text: "@" + (Quickshell.env("USER") || "user"); font.family: root.serif; font.pixelSize: 31; color: root.ink }
        Text {
          width: parent.width; elide: Text.ElideRight
          textFormat: Text.StyledText
          text: "<i>up </i>" + root.uptime.replace(/(\d+)/g, "</i>$1<i>").replace(/^/, "<i>") + "</i>"
          font.family: root.mono; font.pixelSize: 19; color: root.dim
        }
      }
      Column {
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: 20; leftMargin: 19; rightMargin: 27 }
        spacing: 2
        opacity: root.pending < 0 ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Repeater {
          model: root.items
          Rectangle {
            required property var modelData
            required property int index
            readonly property bool on: index === root.sel
            readonly property bool risky: modelData.key === "reboot" || modelData.key === "shutdown"
            readonly property color base: risky ? root.danger : root.selBg
            width: parent.width; height: 31; radius: 6
            color: on ? base : rh.hovered ? Qt.rgba(base.r, base.g, base.b, 0.15) : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
            Text {
              anchors { left: parent.left; leftMargin: 9; verticalCenter: parent.verticalCenter }
              text: modelData.label
              font.family: root.serif; font.pixelSize: 22
              color: parent.on ? (parent.risky ? "#ffffff" : root.selFg) : parent.risky ? root.danger : root.ink
            }
            HoverHandler { id: rh; cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) root.sel = index }
            TapHandler { onTapped: root.ask(index) }
          }
        }
      }
      Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 10
        width: content.width - 54
        spacing: 18
        opacity: root.pending >= 0 ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          text: root.pending >= 0 ? root.confirmText(root.items[root.pending].key) : ""
          font.family: root.serif; font.pixelSize: 23; color: root.ink
        }
        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: 12
          Repeater {
            model: [{ t: "No", v: 0 }, { t: "Yes", v: 1 }]
            Rectangle {
              required property var modelData
              readonly property bool lit: root.yes === modelData.v || bh.hovered
              readonly property color tone: modelData.v === 1 ? root.confirm : root.danger
              width: 84; height: 36; radius: 7
              color: lit ? tone : "transparent"
              border.width: 1
              border.color: lit ? tone : root.line
              Text { anchors.centerIn: parent; text: modelData.t; font.family: root.mono; font.italic: true; font.pixelSize: 19; color: parent.lit ? "#ffffff" : root.ink }
              HoverHandler { id: bh; cursorShape: Qt.PointingHandCursor }
              TapHandler { onTapped: { if (modelData.v === 1) root.run(); else root.pending = -1 } }
            }
          }
        }
      }
    }
    Rectangle {
      anchors.fill: parent
      radius: 9
      color: "transparent"
      border.width: root.dark ? 0.5 : 1
      border.color: root.dark ? Qt.rgba(0.894, 0.89, 0.89, 0.17) : Qt.rgba(0, 0, 0, 0.27)
    }
  }
}

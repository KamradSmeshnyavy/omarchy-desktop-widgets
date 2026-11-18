import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Обзор столов Retro CRT — «все окна таблицей», по его Retro/overview/Overview.qml (github.com/elifouts/Dotfiles,
// GPL-3.0; облик — retro/overview-default.png). overviewStyle: table. Двойная рамка TASKS с подписью ESC-END,
// колонки WS / CLASS / TITLE / MON; столы 1..5 всегда (пустой — строка EMPTY), окна спецстолов — «S:имя».
// Выбранная строка залита акцентом. Enter / клик — к окну или на стол, x / средняя кнопка — закрыть окно,
// 1–9 — на стол, ↑↓ / j k — выбор, Esc / Tab — закрыть. Открывается «включением трубки».
PanelWindow {
  id: ov
  required property var host
  CrtPal { id: cp }

  screen: host.focusedScreen
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  WlrLayershell.namespace: "omarchy-overview"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  property real t: 0
  Component.onCompleted: { Hyprland.refreshToplevels(); grow.start() }
  NumberAnimation { id: grow; target: ov; property: "t"; to: 1; duration: 240; easing.type: Easing.OutCubic }
  function close() { host.overviewOpen = false }
  function hl(code) { Quickshell.execDetached(["hyprctl", "eval", code]) }

  function cls(w) { return String(w.lastIpcObject && w.lastIpcObject.class || w.appId || "?").split(".").pop() }
  readonly property var rows: {
    var out = [], wins = Hyprland.toplevels.values
    var ids = {}
    for (var i = 1; i <= 5; i++) ids[i] = true
    Hyprland.workspaces.values.forEach(function(w) { if (w.id > 0) ids[w.id] = true })
    Object.keys(ids).map(Number).sort(function(a, b) { return a - b }).forEach(function(id) {
      var here = wins.filter(function(w) { return w.workspace && w.workspace.id === id })
      if (!here.length) out.push({ ws: id, win: null })
      here.forEach(function(w) { out.push({ ws: id, win: w }) })
    })
    wins.filter(function(w) { return w.workspace && w.workspace.id < 0 }).forEach(function(w) {
      out.push({ ws: String(w.workspace.name || "s").replace("special:", "s:"), win: w })
    })
    return out
  }
  property int sel: Math.max(0, rows.findIndex(function(r) { return r.win && r.win.activated }))
  function pick(i) {
    var r = rows[i]
    if (!r) return
    if (r.win) hl("hl.dispatch(hl.dsp.focus({ window = 'address:0x" + r.win.address + "' }))")
    else hl("hl.dispatch(hl.dsp.focus({ workspace = '" + r.ws + "' }))")
    close()
  }
  function shut(i) { var r = rows[i]; if (r && r.win) hl("hl.dispatch(hl.dsp.window.close({ window = 'address:0x" + r.win.address + "' }))") }

  MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: ov.close() }

  CrtTube {
    id: frame
    pal: cp
    anchors.centerIn: parent
    width: Math.min(1100, ov.width - 80)
    height: Math.min(ov.height - 100, list.contentHeight + 120)
    t: ov.t

    CrtBox { pal: cp; anchors.fill: parent; double: true; title: "tasks"; note: "esc-end" }
    MouseArea { anchors.fill: parent }

    Row {
      x: 22; y: 22
      Repeater {
        model: [["ws", 70], ["class", 200], ["title", frame.width - 44 - 70 - 200 - 120], ["mon", 120]]
        CrtType { required property var modelData; pal: cp; width: modelData[1]; height: 22; text: modelData[0]; color: cp.accent }
      }
    }
    Rectangle { x: 22; y: 46; width: frame.width - 44; height: 1; color: cp.low }

    ListView {
      id: list
      x: 22; y: 52
      width: frame.width - 44
      height: frame.height - 80
      clip: true
      model: ov.rows
      currentIndex: ov.sel
      boundsBehavior: Flickable.StopAtBounds
      highlightMoveDuration: 0
      delegate: Rectangle {
        id: r
        required property var modelData
        required property int index
        readonly property bool on: index === ov.sel
        readonly property bool first: index === 0 || ov.rows[index - 1].ws !== modelData.ws
        readonly property color ink: on ? cp.bg : modelData.win ? (modelData.win.activated ? cp.accent : cp.fg) : cp.dim
        width: list.width
        height: 22
        color: on ? cp.accent : ra.containsMouse ? cp.low : "transparent"
        Row {
          height: parent.height
          CrtType { type: false; pal: cp; width: 66; height: parent.height; elide: Text.ElideRight; text: r.first ? String(r.modelData.ws).padStart(2, "0") : "  ·"; color: r.ink }
          Item { width: 4; height: 1 }
          CrtType { type: false; pal: cp; width: 200; height: parent.height; elide: Text.ElideRight; text: r.modelData.win ? ov.cls(r.modelData.win) : "empty"; color: r.ink }
          CrtType { type: false; caps: false; pal: cp; width: list.width - 390; height: parent.height; elide: Text.ElideRight; text: r.modelData.win ? (r.modelData.win.title || "") : ""; color: r.ink }
          CrtType { type: false; pal: cp; width: 120; height: parent.height; text: r.modelData.win && r.modelData.win.monitor ? r.modelData.win.monitor.name : ""; color: r.on ? cp.bg : cp.dim }
        }
        MouseArea {
          id: ra
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton | Qt.MiddleButton
          onClicked: function(m) { if (m.button === Qt.MiddleButton) ov.shut(r.index); else ov.pick(r.index) }
          onEntered: ov.sel = r.index
        }
      }
    }
  }

  Item {
    focus: true
    Keys.onEscapePressed: ov.close()
    Keys.onReturnPressed: ov.pick(ov.sel)
    Keys.onEnterPressed: ov.pick(ov.sel)
    Keys.onPressed: function(e) {
      var n = parseInt(e.text)
      if (e.key === Qt.Key_Down || e.text === "j") ov.sel = Math.min(ov.rows.length - 1, ov.sel + 1)
      else if (e.key === Qt.Key_Up || e.text === "k") ov.sel = Math.max(0, ov.sel - 1)
      else if (e.key === Qt.Key_Tab) ov.close()
      else if (e.text === "x") ov.shut(ov.sel)
      else if (n >= 1 && n <= 9) { ov.hl("hl.dispatch(hl.dsp.focus({ workspace = '" + n + "' }))"); ov.close() }
      else return
      e.accepted = true
    }
  }
}

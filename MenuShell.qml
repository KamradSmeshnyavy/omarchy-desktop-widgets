import QtQuick
import Quickshell
import Quickshell.Wayland

// Оболочка меню Super+M райса: окно поверх экрана с затемнением, открыто, пока host.settingsOpen и settingsPanel === kind.
// Содержимое — файл source (Item с host, md, open и, по желанию, back(): bool — шаг назад внутри меню, section(name) —
// открыть раздел wifi / bt / audio по openSettingsSection, keys(event): bool — свои клавиши до KeyNav).
// Клавиатура: свои клавиши меню → KeyNav (стрелки / hjkl / Tab / Enter) → Esc: назад, иначе закрыть. Клик мимо — закрыть.
PanelWindow {
  id: win
  required property var host
  required property string kind
  required property url source
  property real dim: 0.45
  property color ring: host.accent

  readonly property bool open: host.settingsOpen && String(host.value("settingsPanel")) === kind
  property real k: open ? 1 : 0
  Behavior on k { NumberAnimation { duration: win.open ? 320 : 200; easing.type: win.open ? Easing.OutCubic : Easing.InCubic } }

  screen: host.focusedScreen
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  visible: open || k > 0.01
  WlrLayershell.namespace: "omarchy-settings"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  MenuData { id: data; live: win.open }
  property string pending: ""

  Rectangle { anchors.fill: parent; color: "black"; opacity: win.dim * win.k }
  MouseArea { anchors.fill: parent; onClicked: win.host.settingsOpen = false }

  FocusScope {
    id: scope
    anchors.fill: parent
    focus: win.open
    Keys.onPressed: function(e) {
      var it = view.item
      if (it && typeof it.keys === "function" && it.keys(e)) { e.accepted = true; return }
      if (e.key === Qt.Key_Escape) {
        if (it && it.body && it.body.visible && typeof it.body.back === "function" && it.body.back()) { e.accepted = true; return }
        if (it && typeof it.back === "function" && it.back()) { e.accepted = true; return }
        win.host.settingsOpen = false; e.accepted = true; return
      }
      if (nav.handle(e)) e.accepted = true
    }
    Loader {
      id: view
      anchors.fill: parent
      active: win.visible
      source: win.source
      onLoaded: {
        item.host = win.host; item.md = data
        item.k = Qt.binding(function() { return win.k }); item.open = Qt.binding(function() { return win.open })
        if (win.pending !== "" && typeof item.section === "function") item.section(win.pending)
        win.pending = ""
      }
    }
    KeyNav { id: nav; anchors.fill: parent; z: 999; scope: view.item; active: win.open; ring: win.ring }
  }
  onOpenChanged: {
    if (open) {
      scope.forceActiveFocus()
      var s = String(host.settingsSection || "")
      host.settingsSection = ""
      if (s !== "" && view.item && typeof view.item.section === "function") view.item.section(s)
      else win.pending = s
    }
  }
}

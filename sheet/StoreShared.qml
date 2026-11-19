pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "Schema.js" as Schema

// Его shared/StoreShared.qml (github.com/elifouts/Dotfiles, GPL-3.0) для панели Sheet: значения, отложенная запись,
// сброс (null). Хранилище — sheet.py рядом (опции Hyprland, твики Customizer, виджеты, обои, idle, части райса).
Singleton {
  id: root
  readonly property string py: String(Qt.resolvedUrl("sheet.py")).replace(/^file:\/\//, "")
  property var values: ({})
  property var caps: ({ missing: [] })
  property var lists: ({ rices: [], presets: [], fonts: [], bars: [], themes: [], theme: "" })
  property var active: ({ rice: "", style: "" })
  property var pending: ({})
  property bool loaded: false

  function refresh() {
    if (stateProc.running) return
    stateProc.command = ["/usr/bin/python3", "-I", py, "state"].concat(Schema.keys())
    stateProc.running = true
  }
  Process {
    id: stateProc
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var d = JSON.parse(text)
          root.values = Object.assign({}, d.values, root.pending)
          var c = d.caps || {}; c.missing = d.missing || []; root.caps = c
          root.lists = d.lists || root.lists
          root.active = d.active || root.active
          root.loaded = true
        } catch (e) {}
      }
    }
  }

  function set(key, value) { var e = {}; e[key] = value; setMany(e) }
  function reset() { var e = {}; for (var i = 0; i < arguments.length; i++) e[arguments[i]] = null; setMany(e) }
  function setValues(entries) { values = Object.assign({}, values, entries) }
  function setMany(entries) {
    var next = Object.assign({}, values), p = Object.assign({}, pending)
    for (var k in entries) {
      if (entries[k] !== null) next[k] = entries[k]
      else delete next[k]
      p[k] = entries[k]
    }
    values = next
    pending = p
    flushTimer.restart()
  }
  Timer { id: flushTimer; interval: 140; onTriggered: root.flush() }
  function flush() {
    if (setProc.running) { flushTimer.restart(); return }
    var keys = Object.keys(pending)
    if (!keys.length) return
    var args = keys.map(function(k) { return k + "=" + JSON.stringify(pending[k]) })
    pending = ({})
    setProc.command = ["/usr/bin/python3", "-I", py, "set"].concat(args)
    setProc.running = true
  }
  Process { id: setProc; onExited: refreshLater.restart() }
  Timer { id: refreshLater; interval: 400; onTriggered: root.refresh() }

  // его applyProfile / applyTheme / savedRun: райс, пресет, шрифт, бар, тема, мир Space, сохранить
  function act(what, args) {
    Quickshell.execDetached(["/usr/bin/python3", "-I", py, "do", what].concat(args || []))
    var heavy = ["rice", "preset", "profile", "theme", "world", "crtColors"].indexOf(what) !== -1
    refreshLater.interval = heavy ? 2500 : 600
    refreshLater.restart()
    // пресет применяется секунд 10–20 (тема, бар, стиль): ещё раз, когда он закончит
    if (heavy) refreshAfter.restart()
  }
  Timer { id: refreshAfter; interval: 18000; onTriggered: root.refresh() }
}

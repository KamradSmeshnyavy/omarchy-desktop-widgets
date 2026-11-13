import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Где на экране пилюля бара: слой omarchy-bar у Hyprland (hyprctl layers) и форма из bar-skin.json (floating / pill —
// отступы margin и gap от краёв слоя, иначе весь слой). Панели (дашборд, Quick, меню выключения) вырастают из неё —
// анимация «из бара», как у Vitreus. refresh() — перед открытием панели.
Item {
  id: geo

  // в логических px экрана монитора
  property rect barLayer: Qt.rect(0, 0, 0, 0)
  property var skin: ({})
  readonly property string edge: {
    if (barLayer.width <= 0) return "top"
    if (barLayer.width >= barLayer.height) return barLayer.y > 200 ? "bottom" : "top"
    return barLayer.x > 200 ? "right" : "left"
  }
  readonly property bool vertical: edge === "left" || edge === "right"
  readonly property string shape: String(skin.shape || "full")
  readonly property bool floatingPill: ["floating", "pill", "islands", "notches", "notch", "hug"].indexOf(shape) !== -1
  readonly property real margin: floatingPill ? Number(skin.margin) || 0 : 0
  readonly property real gap: floatingPill ? Number(skin.gap) || 0 : 0
  readonly property real thick: Number(skin.height) || (vertical ? barLayer.width : barLayer.height)
  readonly property real radius: Math.min(thick / 2, Number(skin.radius) || thick / 2)
  // сама пилюля
  readonly property rect pill: {
    if (barLayer.width <= 0) return Qt.rect(0, 0, 0, 0)
    if (!vertical) {
      var y = edge === "top" ? barLayer.y + gap : barLayer.y + barLayer.height - gap - thick
      return Qt.rect(barLayer.x + margin, y, barLayer.width - 2 * margin, thick)
    }
    var x = edge === "left" ? barLayer.x + gap : barLayer.x + barLayer.width - gap - thick
    return Qt.rect(x, barLayer.y + margin, thick, barLayer.height - 2 * margin)
  }

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/bar-skin.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { geo.skin = JSON.parse(text()) || {} } catch (e) { geo.skin = {} } }
  }
  Process {
    id: probe
    command: ["hyprctl", "layers", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var d = JSON.parse(text), mons = {}
          var m = Hyprland.monitors.values
          for (var i = 0; i < m.length; i++) if (m[i].lastIpcObject) mons[m[i].name] = m[i].lastIpcObject
          var want = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
          for (var mon in d) {
            if (want && mon !== want) continue
            var lv = d[mon].levels
            for (var k in lv) for (var j = 0; j < lv[k].length; j++) {
              var l = lv[k][j]
              if (l.namespace !== "omarchy-bar") continue
              var mo = mons[mon] || { x: 0, y: 0 }
              geo.barLayer = Qt.rect(l.x - (mo.x || 0), l.y - (mo.y || 0), l.w, l.h)
              return
            }
          }
        } catch (e) {}
      }
    }
  }
  function refresh() { if (!probe.running) probe.running = true }
  Component.onCompleted: refresh()
}

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Prefs — быстрые настройки Glyph по образцу prefs/Prefs.qml glyph-rice (GPL-3.0): Super+Alt+I (omarchy-shell widgets
// togglePrefs). Слева столбец слов Doto — выбранный раздел крупно, с красной точкой; справа раздел «предметом»: макет
// бенто дома, экран с Deck, бар, вид обоев, окна, простой и какие части Glyph включены. Числа — кольца точек (тянуть по
// кругу, колесо, ←→), тумблеры — пилюли. ↑↓ / j k — разделы, Tab — по ручкам, Esc — закрыть.
// Своих настроек нет: всё пишется туда же, куда Customizer (его бэкендом — run.py tweak / apply), вид обоев —
// wallpaper-look.json, простой — idle в shell.json. Customizer остаётся для всего остального.
PanelWindow {
  id: root

  required property var host
  readonly property bool open: host.prefsOpen
  property int sel: 0
  readonly property var sections: ["HOME", "DECK", "BAR", "LOOK", "WINDOWS", "IDLE", "SHELL"]
  function close() { host.prefsOpen = false }
  onOpenChanged: if (open) { refresh(); Qt.callLater(function() { stage.forceActiveFocus() }) }

  // ── запись: бэкенд Customizer ─────────────────────────────────────
  readonly property string backend: Quickshell.env("HOME") + "/.config/omarchy/plugins/kamradsmeshnyavy.customizer/backend/run.py"
  function cz(args, after) {
    var p = proc.createObject(root, { command: ["python3", "-I", backend].concat(args) })
    p.exited.connect(function() { if (after) after(); p.destroy() })
    p.running = true
  }
  function sh(script, args, after) {
    var p = proc.createObject(root, { command: ["sh", "-c", script, "sh"].concat(args || []) })
    p.exited.connect(function() { if (after) after(); p.destroy() })
    p.running = true
  }
  Component { id: proc; Process {} }
  function w(key) { return host.value(key) }
  function setW(key, v) { cz(["tweak", key, "set", String(v)]) }
  function setWin(key, v) { cz(["tweak", key, "set", String(v)], function() { winFile.reload() }) }

  // список через запятую: включить / выключить пункт (порядок — как включали)
  function listOf(s) { return String(s || "").split(/[\s,]+/).filter(function(x) { return x !== "" }) }
  function flipIn(s, id) {
    var l = listOf(s), i = l.indexOf(id)
    if (i >= 0) l.splice(i, 1); else l.push(id)
    return l.join(",")
  }

  // ── чтение того, чего нет в widgets.json ─────────────────────────
  property var win: ({})
  FileView {
    id: winFile
    path: Quickshell.env("HOME") + "/.config/omarchy/customizer/windows.json"
    watchChanges: true; printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.win = JSON.parse(text()) || {} } catch (e) {} }
  }
  property var look: ({ look: "color", pitch: 10, bright: 100 })
  FileView {
    id: lookFile
    path: Quickshell.env("HOME") + "/.config/omarchy/wallpaper-look.json"
    watchChanges: true; printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.look = Object.assign({ look: "color", pitch: 10, bright: 100 }, JSON.parse(text())) } catch (e) {} }
  }
  function setLook(key, v) {
    var o = Object.assign({}, look); o[key] = v; look = o
    lookFile.setText(JSON.stringify(o, null, 2) + "\n")
  }
  property var shell: ({})
  FileView {
    id: shellFile
    path: Quickshell.env("HOME") + "/.config/omarchy/shell.json"
    watchChanges: true; printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.shell = JSON.parse(text()) || {} } catch (e) {} }
  }
  // правка shell.json — python3 одним шагом: прочитать, поменять, записать через временный файл
  function editShell(py, args) {
    sh("python3 -I - \"$@\" <<'PY'\nimport json, os, sys\np = os.path.expanduser('~/.config/omarchy/shell.json')\ns = json.load(open(p))\na = sys.argv[1:]\n" + py
       + "\nt = p + '.prefs-tmp'\nopen(t, 'w').write(json.dumps(s, indent=2, ensure_ascii=False) + '\\n')\nos.replace(t, p)\nPY", args)
  }
  // запись бара по id в любом ряду раскладки
  function barEntry(id) {
    var lay = shell.bar && shell.bar.layout ? shell.bar.layout : {}
    for (var r in lay) {
      var row = lay[r]
      if (!Array.isArray(row)) continue
      for (var i = 0; i < row.length; i++) if (row[i] && row[i].id === id) return row[i]
    }
    return null
  }
  readonly property bool glyphBar: !!barEntry("glyph-tray")
  readonly property var idle: shell.idle || ({ screensaver: 150, lock: 300 })

  // текущие выборы частей, которые Customizer держит в своих файлах
  property string pickerStyle: ""
  property string launcherSkin: ""
  property string lockDesign: ""
  property string themeName: ""
  function refresh() {
    winFile.reload(); lookFile.reload(); shellFile.reload()
    if (!probe.running) probe.running = true
  }
  Process {
    id: probe
    command: ["sh", "-c", "c=$HOME/.config/omarchy; jq -r '.style // \"slices\"' $c/image-picker.json 2>/dev/null || echo slices; "
      + "jq -r '.skin // \"constellation\"' $c/extensions/menu-skin.json 2>/dev/null || echo constellation; "
      + "jq -r '.design // \"classic\"' $c/lock-design.json 2>/dev/null || echo classic; "
      + "head -1 $HOME/.local/state/omarchy/current/theme.name 2>/dev/null"]
    stdout: StdioCollector {
      onStreamFinished: {
        var l = String(text || "").split("\n")
        root.pickerStyle = (l[0] || "").trim(); root.launcherSkin = (l[1] || "").trim()
        root.lockDesign = (l[2] || "").trim(); root.themeName = (l[3] || "").trim()
      }
    }
  }

  screen: host.focusedScreen
  visible: open
  anchors { left: true; right: true; top: true; bottom: true }
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  WlrLayershell.namespace: "omarchy-prefs"

  Rectangle {
    anchors.fill: parent
    color: GTheme.fade(GTheme.bg, 0.96)
    MouseArea { anchors.fill: parent; onClicked: root.close() }
  }

  Stage {
    id: stage
    focus: true
    Keys.onPressed: function(e) {
      if (e.key === Qt.Key_Escape) root.close()
      else if (e.key === Qt.Key_Up || e.key === Qt.Key_K) { root.sel = (root.sel + root.sections.length - 1) % root.sections.length; stage.forceActiveFocus() }
      else if (e.key === Qt.Key_Down || e.key === Qt.Key_J) { root.sel = (root.sel + 1) % root.sections.length; stage.forceActiveFocus() }
      else return
      e.accepted = true
    }
    MouseArea { anchors.fill: parent; onClicked: stage.forceActiveFocus() }

    // разделы — столбец слов Doto, как в меню выключения
    Column {
      x: 150
      anchors.verticalCenter: parent.verticalCenter
      spacing: 14
      Repeater {
        model: root.sections
        Row {
          id: it
          required property string modelData
          required property int index
          readonly property bool on: root.sel === index
          spacing: 22
          Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; radius: 10; color: GTheme.accent; opacity: it.on ? 1 : 0 }
          Num {
            text: it.modelData
            font.pixelSize: it.on ? 96 : 44
            color: it.on ? GTheme.fg : GTheme.mute
            Behavior on font.pixelSize { NumberAnimation { duration: GTheme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: GTheme.glide } }
          }
          TapHandler { onTapped: { root.sel = it.index; stage.forceActiveFocus() } }
          HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
      }
    }

    Row {
      x: 150
      anchors { bottom: parent.bottom; bottomMargin: 60 }
      spacing: 34
      Lb { text: "↑↓ section" }
      Lb { text: "tab · ←→ change" }
      Lb { text: "drag round the rings · scroll" }
      Lb { text: "esc close"; TapHandler { onTapped: root.close() } }
    }

    // ── раздел справа ──
    Item {
      id: page
      x: 820
      y: 120
      width: stage.width - x - 140
      height: stage.height - 240

      // HOME: бенто 3 × 3 — плитки по порядку, как их кладёт HomeGlyph; ниже — лоток: клик включает / убирает
      Column {
        visible: root.sel === 0
        spacing: 26
        Lb { text: "home · on an empty workspace" }
        Row {
          spacing: 18
          Toggle { text: "home"; on: root.w("home") === true; onFlip: root.setW("home", !on) }
          Toggle { text: "greeting"; on: root.w("homeGreeting") !== false; onFlip: root.setW("homeGreeting", !on) }
          Toggle { text: "blink"; on: root.w("homeBlink") === true; onFlip: root.setW("homeBlink", !on) }
        }
        Pick { label: "layout"; opts: ["glyph", "classic", "minimal"]; cur: opts.indexOf(String(root.w("homeLayout"))); onPicked: function(i) { root.setW("homeLayout", opts[i]) } }
        Item {
          width: 3 * 120 + 2 * 12
          height: width
          readonly property var spans: ({ weather: 1, calendar: 1, cpu: 1, ram: 1, battery: 1, temp: 1, disk: 1, cava: 1, player: 2, network: 2, system: 3 })
          readonly property var cells: {
            var ids = root.listOf(root.w("homeWidgets")), out = [], r = 0, c = 0
            for (var i = 0; i < ids.length; i++) {
              var s = spans[ids[i]]; if (!s) continue
              if (c + s > 3) { r++; c = 0 }
              if (r > 2) break
              out.push({ id: ids[i], x: c * 132, y: r * 132, w: s * 120 + (s - 1) * 12 }); c += s
            }
            return out
          }
          Repeater {
            model: 9
            Rectangle { required property int index; x: (index % 3) * 132; y: Math.floor(index / 3) * 132; width: 120; height: 120; radius: 30; color: "transparent"; border { width: 1; color: GTheme.s2 } }
          }
          Repeater {
            model: parent.cells
            Rectangle {
              required property var modelData
              x: modelData.x; y: modelData.y; width: modelData.w; height: 120
              radius: modelData.w === 120 && ["weather", "cpu", "ram", "battery", "cava"].indexOf(modelData.id) >= 0 ? 60 : 30
              color: GTheme.s2
              border { width: 1; color: GTheme.s3 }
              Lb { anchors.centerIn: parent; text: parent.modelData.id; color: GTheme.fg }
              TapHandler { onTapped: root.setW("homeWidgets", root.flipIn(root.w("homeWidgets"), parent.modelData.id)) }
            }
          }
        }
        Tray {
          ids: ["weather", "calendar", "cpu", "ram", "battery", "temp", "disk", "cava", "player", "network", "system"]
          used: root.listOf(root.w("homeWidgets"))
          onToggled: function(id) { root.setW("homeWidgets", root.flipIn(root.w("homeWidgets"), id)) }
        }
      }

      // DECK: экран, у нижнего края — панель с секциями по порядку
      Column {
        visible: root.sel === 1
        spacing: 26
        Lb { text: "deck · from the bottom edge" }
        Row {
          spacing: 18
          Toggle { text: "deck"; on: root.w("deck") === true; onFlip: root.setW("deck", !on) }
          Pick { label: "open"; opts: ["dwell", "bump"]; cur: opts.indexOf(String(root.w("deckTrigger"))); onPicked: function(i) { root.setW("deckTrigger", opts[i]) } }
        }
        Pick { label: "layout"; opts: ["panel", "compact", "full"]; cur: opts.indexOf(String(root.w("deckLayout"))); onPicked: function(i) { root.setW("deckLayout", opts[i]) } }
        Rectangle {
          width: 640; height: 360; radius: 24
          color: "transparent"
          border { width: 1; color: GTheme.s3 }
          readonly property string lay: String(root.w("deckLayout"))
          Rectangle {
            readonly property var ids: root.listOf(root.w("deckSections"))
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: parent.lay === "full" ? 20 : 12 }
            width: parent.lay === "compact" ? 360 : 560
            height: parent.lay === "full" ? 320 : parent.lay === "compact" ? 70 : 140
            radius: 20
            color: GTheme.s1
            border { width: 1; color: GTheme.s2 }
            Row {
              anchors.centerIn: parent
              spacing: 10
              Repeater {
                model: parent.parent.ids
                Rectangle { required property string modelData; width: 76; height: 40; radius: 20; color: GTheme.s2; Lb { anchors.centerIn: parent; text: parent.modelData; px: 9; color: GTheme.fg } }
              }
            }
          }
        }
        Tray {
          ids: ["clock", "weather", "perf", "net", "media"]
          used: root.listOf(root.w("deckSections"))
          onToggled: function(id) { root.setW("deckSections", root.flipIn(root.w("deckSections"), id)) }
        }
        Dial { size: 120; label: "delay · ms"; from: 0; to: 1000; step: 50; value: Number(root.w("deckDelay")) || 0; onMoved: function(v) { root.setW("deckDelay", v) } }
      }

      // BAR: раскладка glyph-rice и её части
      Column {
        visible: root.sel === 2
        spacing: 26
        Lb { text: root.glyphBar ? "bar · glyph-rice layout" : "bar · another layout is on" }
        Chip {
          visible: !root.glyphBar
          text: "use the glyph-rice layout"
          on: true
          onClicked: root.cz(["apply", "bar-layouts", Quickshell.env("HOME") + "/.config/omarchy/plugins/kamradsmeshnyavy.bar/layouts/glyph-rice.json"], root.refresh)
        }
        Column {
          visible: root.glyphBar
          spacing: 26
          Lb { text: "tray · in order" }
          Tray {
            ids: ["wifi", "bluetooth", "sound", "battery"]
            readonly property var e: root.barEntry("glyph-tray")
            used: root.listOf(e && e.parts ? e.parts : "wifi,bluetooth,sound,battery")
            onToggled: function(id) {
              root.editShell("for r in s['bar']['layout'].values():\n    for e in (r if isinstance(r, list) else []):\n        if isinstance(e, dict) and e.get('id') == 'glyph-tray':\n            e['parts'] = a[0]",
                             [root.flipIn(used.join(","), id)])
            }
          }
          Row {
            spacing: 36
            Toggle {
              text: "window title"
              on: !!root.barEntry("glyph-title")
              onFlip: root.editShell(on
                ? "for r in s['bar']['layout'].values():\n    if isinstance(r, list):\n        r[:] = [e for e in r if not (isinstance(e, dict) and e.get('id') == 'glyph-title')]"
                : "l = s['bar']['layout'].setdefault('left', [])\nl.append({'id': 'glyph-title', 'type': 'qml', 'source': '~/.config/omarchy/plugins/kamradsmeshnyavy.bar/modules/GlyphTitle.qml', 'length': 220})", [])
            }
            Dial {
              visible: !!root.barEntry("glyph-title")
              size: 120; label: "title · px"; from: 100; to: 400; step: 10
              value: { var e = root.barEntry("glyph-title"); return e && e.length ? e.length : 220 }
              onMoved: function(v) {
                root.editShell("for r in s['bar']['layout'].values():\n    for e in (r if isinstance(r, list) else []):\n        if isinstance(e, dict) and e.get('id') == 'glyph-title':\n            e['length'] = int(a[0])", [String(v)])
              }
            }
          }
        }
      }

      // LOOK: вид обоев и тема
      Column {
        visible: root.sel === 3
        spacing: 30
        Lb { text: "wallpaper · " + String(root.look.look) }
        Pick { label: "look"; opts: ["dots", "mono", "color"]; cur: opts.indexOf(String(root.look.look)); onPicked: function(i) { root.setLook("look", opts[i]) } }
        Row {
          spacing: 36
          Dial { size: 140; label: "dot · px"; from: 4; to: 32; live: true; value: Number(root.look.pitch) || 10; onMoved: function(v) { root.setLook("pitch", v) } }
          Dial { size: 140; label: "light · %"; from: 10; to: 100; step: 5; live: true; value: Number(root.look.bright) || 100; onMoved: function(v) { root.setLook("bright", v) } }
        }
        Pick {
          label: "theme"; opts: ["dark", "light"]
          cur: root.themeName === "nothing-glyph-light" ? 1 : root.themeName === "nothing-glyph-dark" ? 0 : -1
          onPicked: function(i) { root.cz(["apply", "themes", i ? "nothing-glyph-light" : "nothing-glyph-dark"], root.refresh) }
        }
        Chip { text: "wallpapers…"; on: false; onClicked: { root.close(); Quickshell.execDetached(["setsid", "-f", "omarchy-theme-bg-switcher"]) } }
      }

      // WINDOWS: зазоры, рамка, скругление
      Column {
        visible: root.sel === 4
        spacing: 30
        Lb { text: "windows" }
        Row {
          spacing: 30
          Dial { size: 140; label: "gaps in"; from: 0; to: 40; value: Number(root.win.windowGapsIn) || 0; onMoved: function(v) { root.setWin("windowGapsIn", v) } }
          Dial { size: 140; label: "gaps out"; from: 0; to: 80; value: Number(root.win.windowGapsOut) || 0; onMoved: function(v) { root.setWin("windowGapsOut", v) } }
          Dial { size: 140; label: "border"; from: 0; to: 8; value: Number(root.win.windowBorder) || 0; onMoved: function(v) { root.setWin("windowBorder", v) } }
          Dial { size: 140; label: "round"; from: 0; to: 32; value: Number(root.win.windowDecoRounding) || 0; onMoved: function(v) { root.setWin("windowDecoRounding", v) } }
        }
        Row {
          spacing: 18
          Toggle { text: "no gaps"; on: root.win.windowNoGaps === true; onFlip: root.setWin("windowNoGaps", !on) }
          Toggle { text: "shadow"; on: root.win.windowShadow === true; onFlip: root.setWin("windowShadow", !on) }
        }
      }

      // IDLE: через сколько минут заставка и блокировка (0 — никогда); пишется в idle shell.json
      Column {
        visible: root.sel === 5
        spacing: 30
        Lb { text: "idle · minutes · 0 is never" }
        Row {
          spacing: 36
          Dial {
            size: 160; label: "screensaver"; from: 0; to: 60
            value: Math.round((Number(root.idle.screensaver) || 0) / 60)
            text: v > 0 ? Math.round(v) : "off"
            onMoved: function(v) { root.editShell("s.setdefault('idle', {})['screensaver'] = int(a[0]) * 60", [String(v)]) }
          }
          Dial {
            size: 160; label: "lock"; from: 0; to: 120
            value: Math.round((Number(root.idle.lock) || 0) / 60)
            text: v > 0 ? Math.round(v) : "off"
            onMoved: function(v) { root.editShell("s.setdefault('idle', {})['lock'] = int(a[0]) * 60", [String(v)]) }
          }
        }
      }

      // SHELL: какие части — из glyph-rice
      Column {
        visible: root.sel === 6
        spacing: 22
        Lb { text: "which parts are glyph" }
        Pick { label: "super+m"; opts: ["drawer", "quick"]; cur: opts.indexOf(String(root.w("settingsPanel"))); onPicked: function(i) { root.setW("settingsPanel", opts[i]) } }
        Pick { label: "power"; opts: ["edge", "glyph"]; cur: opts.indexOf(String(root.w("powerStyle"))); onPicked: function(i) { root.setW("powerStyle", opts[i]) } }
        Pick { label: "clipboard"; opts: ["stock", "glyph"]; cur: opts.indexOf(String(root.w("clipboardPanel"))); onPicked: function(i) { root.setW("clipboardPanel", opts[i]) } }
        Pick {
          label: "walls"; opts: ["glyph", "dots", "slices"]; cur: opts.indexOf(root.pickerStyle)
          onPicked: function(i) { root.pickerStyle = opts[i]; root.cz(["apply", "theme-switcher", "style:" + opts[i]]) }
        }
        Pick {
          label: "launcher"; opts: ["glyph", "dotmatrix", "list"]; cur: opts.indexOf(root.launcherSkin)
          onPicked: function(i) { root.launcherSkin = opts[i]; root.cz(["apply", "launcher", "skin:" + opts[i]]) }
        }
        Pick {
          label: "lock"; opts: ["glyph", "dotmatrix", "classic"]; cur: opts.indexOf(root.lockDesign)
          onPicked: function(i) { root.lockDesign = opts[i]; root.cz(["apply", "lock", opts[i]]) }
        }
        Chip { text: "everything else — customizer"; on: false; onClicked: { root.close(); Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "kamradsmeshnyavy.customizer"]) } }
      }
    }
  }

  // лоток: все пункты чипами, включённые — белые, с номером по порядку; клик — включить / убрать
  component Tray: Flow {
    id: tray
    property var ids: []
    property var used: []
    signal toggled(string id)
    width: 760
    spacing: 10
    Repeater {
      model: tray.ids
      Rectangle {
        required property string modelData
        readonly property int at: tray.used.indexOf(modelData)
        width: lab.implicitWidth + 40
        height: 44
        radius: 22
        color: at >= 0 ? GTheme.fg : GTheme.s2
        Behavior on color { ColorAnimation { duration: GTheme.t } }
        Lb { id: lab; anchors.centerIn: parent; text: (parent.at >= 0 ? (parent.at + 1) + " · " : "") + parent.modelData; px: 11; color: parent.at >= 0 ? GTheme.ink : GTheme.grey }
        TapHandler { onTapped: tray.toggled(parent.modelData) }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
      }
    }
  }
  // кнопка-пилюля
  component Chip: Rectangle {
    id: chip
    property string text
    property bool on
    signal clicked
    width: clab.implicitWidth + 48
    height: 52
    radius: 26
    color: on ? GTheme.fg : GTheme.s2
    Lb { id: clab; anchors.centerIn: parent; text: chip.text; color: chip.on ? GTheme.ink : GTheme.fg }
    TapHandler { onTapped: chip.clicked() }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
  }
}

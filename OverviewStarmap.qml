import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// Звёздная карта — обзор столов райса Space (по мотивам Space/overview/Overview.qml из github.com/elifouts/Dotfiles,
// GPL-3.0; небо — его overview.frag, звёзды — его orb.frag, раскладка звёзд — его World.starOf; код карты свой, без его
// свободного полёта и планет-пейзажей). Столы — звёзды в трёхмерном небе, соединённые трассой по порядку; special-столы
// с окнами — отдельные системы со своим именем. Выбранная система раскрывается: окна — планеты на наклонных орбитах,
// в каждой — снимок окна. Камера перелетает от звезды к звезде, Enter — «посадка» (камера ныряет к звезде, карта тает,
// стол переключается). Клавиши: hjkl / wasd / стрелки — ближайшая звезда в ту сторону, Tab / Shift+Tab — следующая /
// предыдущая система, Enter / пробел — сесть, 1–9 — сразу на стол, колесо — ближе / дальше, Esc — назад.
// Клик по звезде — лететь к ней (по выбранной — сесть), по планете — фокус на окне.
// Дикие системы (его wild): неизведанные звёзды вокруг, у каждой свой мир — одна из его девяти палитр и акцент из неё.
// Посадка на дикую звезду занимает свободный стол на её месте и перекрашивает рабочий стол в этот мир с новой землёй
// (omarchy-space-world из omarchy-rices/space). Стол запоминает звезду и мир (~/.local/state/omarchy/space-stars.json):
// посадка на него с карты возвращает его мир. R — новая галактика (другие дикие системы).
PanelWindow {
  id: map
  required property var host

  screen: host.focusedScreen
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  surfaceFormat.opaque: false
  WlrLayershell.namespace: "omarchy-overview"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  readonly property color acc: host.accent
  readonly property color fg: host.foreground
  readonly property color bg: host.background
  readonly property string mono: Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : "monospace"
  function a(c, k) { return Qt.rgba(c.r, c.g, c.b, k) }
  function mixc(x, y, k) { x = Qt.color(x); y = Qt.color(y); return Qt.rgba(x.r + (y.r - x.r) * k, x.g + (y.g - x.g) * k, x.b + (y.b - x.b) * k, 1) }

  // ── системы: занятые столы + special-столы с окнами ──
  readonly property var monitor: Hyprland.monitorFor(screen)
  readonly property int current: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1
  function pad(n) { return (n < 10 ? "0" : "") + n }
  function r3(x, y, z) { var v = Math.sin(x * 12.9898 + y * 78.233 + z * 37.719) * 43758.5453; return v - Math.floor(v) }
  // его World.starOf: спираль, дальше от центра с номером; стол, занятый посадкой на дикую звезду, — на её месте
  function starOf(id) {
    var st = stored[String(id)]
    if (st && st.pos) return st.pos
    var t = id * 2.4; return [Math.cos(t) * (60 + id * 22), Math.sin(id * 1.3) * 26, Math.sin(t) * (60 + id * 22)]
  }

  // ── миры и память звёзд ──
  readonly property string home: Quickshell.env("HOME")
  property var worlds: []   // omarchy-space-world --list: {theme, acc, color, bg, title}
  property var stored: ({}) // стол → {pos, theme, acc, seed}
  property int galaxy: 1    // сид диких систем (R — новая галактика)
  property var curWorld: null
  Process {
    running: true
    command: ["omarchy-space-world", "--list"]
    stdout: StdioCollector { onStreamFinished: { try { map.worlds = JSON.parse(text) } catch (e) { map.worlds = [] } } }
  }
  FileView {
    id: starsFile
    path: map.home + "/.local/state/omarchy/space-stars.json"
    printErrors: false
    onLoaded: { try { var d = JSON.parse(text() || "{}"); map.stored = d.stars || {}; map.galaxy = d.galaxy || 1 } catch (e) {} }
  }
  function saveStars() { starsFile.setText(JSON.stringify({ galaxy: galaxy, stars: stored }, null, 1)) }
  FileView {
    path: map.home + "/.local/state/omarchy/current/theme/world.json"
    printErrors: false
    onLoaded: { try { map.curWorld = JSON.parse(text() || "null") } catch (e) { map.curWorld = null } }
  }
  function worldOf(theme, acc) {
    for (var i = 0; i < worlds.length; i++) if (worlds[i].theme === theme && worlds[i].acc === acc) return worlds[i]
    return null
  }
  function sameWorld(st) { return !!curWorld && curWorld.theme === st.theme && curWorld.acc === st.acc && curWorld.seed === st.seed }
  function d3(p, q) { var x = p[0] - q[0], y = p[1] - q[1], z = p[2] - q[2]; return Math.sqrt(x * x + y * y + z * z) }
  function specialPos(name) {
    var h = 7
    for (var i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) | 0
    var t = r3(h, 1, 2) * Math.PI * 2, r = 90 + r3(h, 3, 4) * 80
    return [Math.cos(t) * r, (r3(h, 5, 6) - 0.5) * 40, Math.sin(t) * r]
  }
  readonly property var used: {
    var list = Hyprland.workspaces.values, ws = [], sp = []
    for (var i = 0; i < list.length; i++) {
      var w = list[i]
      if (w.id > 0) {
        var st = stored[String(w.id)]
        ws.push({ id: w.id, key: "ws" + w.id, kind: "ws", name: "system " + pad(w.id), ws: w, pos: starOf(w.id), special: "",
                  world: st ? worldOf(st.theme, st.acc) : null, st: st || null })
      } else if (String(w.name).indexOf("special:") === 0 && w.toplevels.values.length > 0) {
        var n = String(w.name).slice(8)
        sp.push({ id: w.id, key: "sp" + n, kind: "special", name: n, ws: w, pos: specialPos(w.name), special: n, world: null, st: null })
      }
    }
    ws.sort(function(x, y) { return x.id - y.id })
    return ws.concat(sp)
  }
  // дикие системы (его rebuild): небо поделено на клетки по 40, в клетке звезда с вероятностью 0.22 — вокруг выбранной
  // системы ±3 клетки по горизонтали и ±1 по высоте, так что куда ни прилетишь, рядом есть неизведанное. Звезда и её
  // мир — хэш клетки и галактики; у занятых звёзд дикие не рождаются; мир — не тот, что стоит сейчас.
  readonly property int cell: 40
  property var here: [0, 0, 0]
  readonly property var wilds: {
    if (!worlds.length) return []
    var out = [], taken = used.map(function(s) { return s.pos }), g = galaxy * 101
    var a0 = Math.floor(here[0] / cell), b0 = Math.floor(here[1] / cell), c0 = Math.floor(here[2] / cell)
    for (var i = -3; i <= 3; i++) for (var j = -1; j <= 1; j++) for (var k = -3; k <= 3; k++) {
      var ca = a0 + i, cb = b0 + j, cc = c0 + k
      if (r3(ca + g, cb, cc) > 0.22) continue
      var p = [(ca + 0.15 + 0.7 * r3(cb, cc + g, ca)) * cell, (cb + 0.15 + 0.7 * r3(cc, ca, cb + g)) * cell * 0.6,
               (cc + 0.15 + 0.7 * r3(ca, ca + g, cc)) * cell]
      var near = false
      for (var q = 0; q < taken.length && !near; q++) near = d3(p, taken[q]) < 18
      if (near) continue
      var n = Math.floor(r3(cc, cb + g, ca) * worlds.length), w = worlds[n]
      if (curWorld && w.theme === curWorld.theme && w.acc === curWorld.acc) w = worlds[(n + 7) % worlds.length]
      out.push({ id: -1, key: "w" + galaxy + ":" + ca + "," + cb + "," + cc, kind: "wild", name: "uncharted system", ws: null,
                 pos: p, special: "", world: w, seed: 1 + Math.floor(r3(cb + g, ca, cc) * 996) })
    }
    return out
  }
  readonly property var systems: used.concat(wilds)
  function sysByKey(k) { for (var i = 0; i < systems.length; i++) if (systems[i].key === k) return systems[i]; return null }
  property string selKey: "ws" + current
  readonly property var sel: sysByKey(selKey) || (systems.length ? systems[0] : null)
  function appOf(t) { var o = t && t.lastIpcObject; var c = String(o && o.class ? o.class : (t && t.title ? t.title : "")); return c.split(".").pop() }
  function appsOf(s) {
    if (!s) return ""
    if (!s.ws) return ""
    var seen = [], ts = s.ws.toplevels.values
    for (var i = 0; i < ts.length && seen.length < 2; i++) { var n = appOf(ts[i]); if (n && seen.indexOf(n) < 0) seen.push(n) }
    return seen.join(" · ")
  }

  // ── камера (его project / toCam): позиция, рыскание, тангаж, фокусное ──
  readonly property real cx: width / 2
  readonly property real cy: height / 2
  readonly property real focal: Math.max(width, height) * 0.6
  property var cam: ({ x: 0, y: 0, z: -40, cyw: 1, syw: 0, cp: 1, sp: 0 })
  function setView(p, yaw, pitch) {
    cam = { x: p[0], y: p[1], z: p[2], cyw: Math.cos(yaw), syw: Math.sin(yaw), cp: Math.cos(pitch), sp: Math.sin(pitch) }
  }
  function rel(p) {
    var c = cam, vx = p[0] - c.x, vy = p[1] - c.y, vz = p[2] - c.z
    var x1 = vx * c.cyw - vz * c.syw, z1 = vx * c.syw + vz * c.cyw
    return [x1, vy * c.cp - z1 * c.sp, vy * c.sp + z1 * c.cp]
  }
  function project(p) {
    var q = rel(p)
    if (q[2] < 1.5) return null
    return { x: cx + q[0] / q[2] * focal, y: cy - q[1] / q[2] * focal, s: focal / q[2] / 8, z: q[2] }
  }
  function segment(pa, pb) {
    var n = 1.5, qa = rel(pa), qb = rel(pb)
    if (qa[2] < n && qb[2] < n) return null
    function mix3(u, v, t) { return [u[0] + (v[0] - u[0]) * t, u[1] + (v[1] - u[1]) * t, u[2] + (v[2] - u[2]) * t] }
    if (qa[2] < n) qa = mix3(qa, qb, (n - qa[2]) / (qb[2] - qa[2]))
    else if (qb[2] < n) qb = mix3(qb, qa, (n - qb[2]) / (qa[2] - qb[2]))
    return [Qt.point(cx + qa[0] / qa[2] * focal, cy - qa[1] / qa[2] * focal), Qt.point(cx + qb[0] / qb[2] * focal, cy - qb[1] / qb[2] * focal)]
  }

  // ── полёт: камера всегда смотрит на цель, между системами отходит назад (lift) ──
  property real dist: 34
  property real pitch: -0.32
  property var fromT: [0, 0, 0]
  property var toT: [0, 0, 0]
  property real fromYaw: 0
  property real toYaw: 0
  property real fromD: 34
  property real toD: 34
  property real fromP: -0.32
  property real toP: -0.32
  property real lift: 0
  property real flyT: 1
  function yawOf(p) { return Math.atan2(p[0], p[2]) }
  function apply() {
    var k = flyT, e = k < 0.5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2
    var t = [fromT[0] + (toT[0] - fromT[0]) * e, fromT[1] + (toT[1] - fromT[1]) * e, fromT[2] + (toT[2] - fromT[2]) * e]
    var yw = fromYaw + (toYaw - fromYaw) * e, pt = fromP + (toP - fromP) * e
    var d = fromD + (toD - fromD) * e + Math.sin(Math.PI * e) * lift
    var f = [Math.sin(yw) * Math.cos(pt), Math.sin(pt), Math.cos(yw) * Math.cos(pt)]
    setView([t[0] - f[0] * d, t[1] - f[1] * d, t[2] - f[2] * d], yw, pt)
  }
  onFlyTChanged: apply()
  property var curT: [0, 0, 0]
  property real curYaw: 0
  property real curD: 34
  property real curP: -0.32
  function flyTo(target, d, p, ms, hop) {
    fromT = curT; fromYaw = curYaw; fromD = curD; fromP = curP
    var y = yawOf(target)
    while (y - fromYaw > Math.PI) y -= Math.PI * 2
    while (y - fromYaw < -Math.PI) y += Math.PI * 2
    toT = target; toYaw = y; toD = d; toP = p
    var dx = target[0] - fromT[0], dy = target[1] - fromT[1], dz = target[2] - fromT[2]
    lift = hop ? Math.min(60, Math.sqrt(dx * dx + dy * dy + dz * dz) * 0.35) : 0
    curT = target; curYaw = y; curD = d; curP = p
    flight.duration = ms
    flight.restart()
  }
  NumberAnimation { id: flight; target: map; property: "flyT"; from: 0; to: 1; duration: 1000 }
  function select(s) {
    if (!s || landing) return
    if (s.key === selKey && flight.running) return
    selKey = s.key
    here = s.pos
    flyTo(s.pos, dist, pitch, 1100, true)
    bloomAnim.restart()
  }

  // раскрытие системы: орбиты дорисовываются, планеты вырастают (его bloom)
  property real bloom: 0
  SequentialAnimation {
    id: bloomAnim
    PropertyAction { target: map; property: "bloom"; value: 0 }
    PauseAnimation { duration: 380 }
    NumberAnimation { target: map; property: "bloom"; to: 1; duration: 900; easing.type: Easing.OutQuint }
  }

  // ── открытие и посадка ──
  property real ui: 0
  property bool landing: false
  Component.onCompleted: {
    Hyprland.refreshToplevels()
    var s = sel
    var p = s ? s.pos : [0, 0, 0]
    here = p
    // встать над звездой текущего стола
    curT = fromT = toT = p; curYaw = fromYaw = toYaw = yawOf(p); curD = fromD = toD = 7; curP = fromP = toP = -1.05
    apply()
    flyTo(p, dist, pitch, 1000, false)  // и подняться над системой
    uiIn.start()
    bloomAnim.restart()
  }
  NumberAnimation { id: uiIn; target: map; property: "ui"; from: 0; to: 1; duration: 450; easing.type: Easing.OutCubic }
  function hl(lua) { Quickshell.execDetached(["hyprctl", "eval", lua]) }
  property var landAction: null
  function freeWs() {
    var ids = Hyprland.workspaces.values.map(function(w) { return w.id })
    for (var i = 1; i <= 10; i++) if (ids.indexOf(i) < 0 && !stored[String(i)]) return i
    for (i = 1; i <= 10; i++) if (ids.indexOf(i) < 0) return i
    return 10
  }
  function world(st, id) {
    Quickshell.execDetached(["omarchy-space-world", st.theme, String(st.acc), String(st.seed), String(id)])
  }
  function land(s) {
    if (!s || landing) return
    landing = true
    selKey = s.key
    if (s.kind === "wild") {
      // дикая звезда: свободный стол встаёт на её место и получает её мир
      var id = freeWs(), st = { pos: s.pos, theme: s.world.theme, acc: s.world.acc, seed: s.seed }
      var next = Object.assign({}, stored); next[String(id)] = st; stored = next
      saveStars()
      landAction = function() { map.hl("hl.dispatch(hl.dsp.focus({ workspace = '" + id + "' }))"); map.world(st, id) }
    } else if (s.special !== "")
      landAction = function() { map.hl("hl.dispatch(hl.dsp.workspace.toggle_special('" + s.special + "'))") }
    else {
      var keep = s.st && s.st.theme && !sameWorld(s.st) ? s.st : null
      landAction = function() { map.hl("hl.dispatch(hl.dsp.focus({ workspace = '" + s.id + "' }))"); if (keep) map.world(keep, s.id) }
    }
    flyTo(s.pos, 3, -0.15, 650, false)
    landAnim.restart()
  }
  function focusWindow(t) {
    if (landing) return
    var addr = t && t.lastIpcObject ? String(t.lastIpcObject.address || "") : ""
    landing = true
    landAction = function() { if (addr) map.hl("hl.dispatch(hl.dsp.focus({ window = 'address:" + addr + "' }))") }
    landAnim.restart()
  }
  SequentialAnimation {
    id: landAnim
    PauseAnimation { duration: 280 }
    ScriptAction { script: if (map.landAction) map.landAction() }
    NumberAnimation { target: map; property: "ui"; to: 0; duration: 340; easing.type: Easing.InCubic }
    ScriptAction { script: map.host.overviewOpen = false }
  }
  function close() {
    if (landing) return
    landing = true
    landAction = null
    landAnim.restart()
  }

  // ── выбор звезды в сторону (hjkl / стрелки): ближайшая по экрану в пределах ±60° ──
  function pickDir(dx, dy) {
    var o = sel ? project(sel.pos) : null
    if (!o) return
    var best = null, bs = 1e9
    for (var i = 0; i < systems.length; i++) {
      var s = systems[i]
      if (s === sel) continue
      var p = project(s.pos)
      var vx, vy
      if (p) { vx = p.x - o.x; vy = p.y - o.y }
      else { var q = rel(s.pos); vx = q[0]; vy = -q[1] }
      var l = Math.sqrt(vx * vx + vy * vy) || 1, c = (vx * dx + vy * dy) / l
      if (c < 0.5) continue
      var sc = l * (1 + 2 * (1 - c))
      if (sc < bs) { bs = sc; best = s }
    }
    if (best) select(best)
  }
  function step(d) {
    if (!used.length) return
    var i = Math.max(0, used.indexOf(sel))
    select(used[(i + d + used.length) % used.length])
  }
  function newGalaxy() {
    galaxy = galaxy + 1
    saveStars()
    if (sel && sel.kind === "wild") select(used.length ? used[0] : null)
  }

  // ── фоновые звёзды: 180 точек вокруг карты, параллакс при полёте ──
  readonly property var wild: {
    var out = []
    for (var i = 0; i < 180; i++) {
      var t = r3(i, 1, 9) * Math.PI * 2, u = r3(i, 2, 7) * 2 - 1, r = 120 + r3(i, 3, 5) * 380
      var c = Math.sqrt(1 - u * u)
      out.push({ p: [Math.cos(t) * c * r, u * r * 0.6, Math.sin(t) * c * r], s: 0.5 + r3(i, 4, 3), k: r3(i, 5, 1) })
    }
    return out
  }

  // ── планеты выбранной системы: окна на наклонных орбитах ──
  readonly property real tilt: sel ? 0.22 + r3(Math.round(sel.pos[0]), Math.round(sel.pos[2]), 2) * 0.3 : 0.3
  function orbitPt(c, r, t) { var z = Math.sin(t) * r; return [c[0] + Math.cos(t) * r, c[1] + z * Math.sin(tilt), c[2] + z * Math.cos(tilt)] }
  readonly property var planets: {
    if (!sel) return []
    var base = r3(sel.id, 7, 7) * Math.PI * 2
    if (sel.kind === "wild") return [{ t: null, home: true, r: 10, ang: base }]  // его home: одна планета — сам мир
    var ts = sel.ws.toplevels.values, out = []
    for (var i = 0; i < ts.length && i < 9; i++) out.push({ t: ts[i], r: 10 + i * 3.6, ang: base + i * 2.399 })
    return out
  }
  function ringPaths(r, f) {
    if (!sel || f <= 0) return []
    var n = 72, out = [], cur = [], base = 0
    for (var i = 0; i <= Math.ceil(n * f); i++) {
      var p = project(orbitPt(sel.pos, r, base + i / n * Math.PI * 2))
      if (p) cur.push(Qt.point(p.x, p.y))
      else if (cur.length) { out.push(cur); cur = [] }
    }
    if (cur.length > 1) out.push(cur)
    return out
  }

  // ── небо ──
  ShaderEffect {
    anchors.fill: parent
    opacity: map.ui
    readonly property real yaw: Math.atan2(map.cam.syw, map.cam.cyw)
    readonly property real pitch: Math.atan2(map.cam.sp, map.cam.cp)
    readonly property real focal: map.focal
    readonly property real offX: -map.cx
    readonly property real offY: -map.cy
    readonly property real sizeW: width
    readonly property real sizeH: height
    readonly property color tint1: map.acc
    readonly property color tint2: map.mixc(map.acc, map.fg, 0.45)
    readonly property color base: map.mixc(map.bg, "#000000", 0.7)
    fragmentShader: Qt.resolvedUrl("shaders/starmap.frag.qsb")
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: function(m) { if (m.button === Qt.RightButton) map.close() }
      onWheel: function(w) {
        map.dist = Math.max(18, Math.min(80, map.dist * (w.angleDelta.y > 0 ? 0.88 : 1.14)))
        if (map.sel && !map.landing) map.flyTo(map.sel.pos, map.dist, map.pitch, 260, false)
      }
    }
  }

  Item {
    id: scene
    anchors.fill: parent
    opacity: map.ui

    // фоновые звёзды
    Repeater {
      model: map.wild
      Rectangle {
        required property var modelData
        readonly property var p: map.project(modelData.p)
        readonly property real far: p ? Math.min(1, p.z / 520) : 1
        readonly property real d: p ? Math.max(1.5, Math.min(3.5, 1 + modelData.s * p.s * 0.5)) : 0
        visible: !!p && far < 1
        x: (p ? p.x : 0) - d / 2
        y: (p ? p.y : 0) - d / 2
        width: d; height: d; radius: d / 2
        color: modelData.k < 0.2 ? "#d6e4ff" : modelData.k > 0.85 ? "#ffe9cf" : "#ffffff"
        opacity: (1 - far * far) * (0.35 + 0.5 * modelData.s)
      }
    }

    // трасса между столами по порядку
    Repeater {
      model: Math.max(0, map.used.filter(function(s) { return s.kind === "ws" }).length - 1)
      Rectangle {
        required property int index
        readonly property var g: map.segment(map.used[index].pos, map.used[index + 1].pos)
        visible: !!g
        x: g ? g[0].x : 0
        y: g ? g[0].y : 0
        width: g ? Math.hypot(g[1].x - g[0].x, g[1].y - g[0].y) : 0
        height: 1
        rotation: g ? Math.atan2(g[1].y - g[0].y, g[1].x - g[0].x) * 180 / Math.PI : 0
        transformOrigin: Item.Left
        antialiasing: true
        color: map.a(map.acc, 0.32)
      }
    }

    // орбиты выбранной системы
    Repeater {
      model: map.planets
      Shape {
        required property var modelData
        required property int index
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property bool lit: map.hoverKey === String(index)
        ShapePath {
          strokeWidth: parent.lit ? 1.5 : 1
          strokeColor: map.a(map.mixc(map.acc, map.fg, 0.4), parent.lit ? 0.7 : 0.2)
          fillColor: "transparent"
          PathMultiline { paths: map.ringPaths(modelData.r, Math.max(0, Math.min(1, map.bloom * 1.4 - 0.12 * index))) }
        }
      }
    }

    // звёзды-системы
    Repeater {
      model: map.systems
      Item {
        id: st
        required property var modelData
        readonly property var p: map.project(modelData.pos)
        readonly property real far: p ? Math.min(1, p.z / 260) : 1
        readonly property bool picked: map.sel && map.sel.key === modelData.key
        readonly property bool here: modelData.kind === "ws" && modelData.id === map.current
        readonly property bool wild: modelData.kind === "wild"
        readonly property bool hov: map.hoverKey === "s" + modelData.key
        z: 5
        property real boost: (picked ? 1.7 : 1) * (wild ? 0.75 : 1)
        Behavior on boost { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        ShaderEffect {
          id: orb
          visible: !!st.p && st.p.z > 3
          width: Math.min(30, 5 + 7 * (st.p ? st.p.s : 0)) * st.boost * 1.6
          height: width
          x: (st.p ? st.p.x : 0) - width / 2
          y: (st.p ? st.p.y : 0) - height / 2
          // дикие — цветом своего мира; столы, занятые посадкой, — тоже (его hue звезды)
          readonly property color tint: st.modelData.world ? map.mixc("#ffffff", st.modelData.world.color, st.wild ? 0.55 : 0.4)
            : st.modelData.special !== "" ? map.mixc(map.fg, map.acc, 0.6) : map.mixc("#ffffff", map.acc, 0.25)
          readonly property real core: 0.24
          readonly property real glow: 1
          readonly property real shade: 0
          opacity: Math.max(0.55, 1 - st.far * st.far) * Math.min(1, ((st.p ? st.p.z : 0) - 3) / 10) * (st.wild && !st.picked && !st.hov ? 0.7 : 1)
          fragmentShader: Qt.resolvedUrl("shaders/orb.frag.qsb")
          MouseArea {
            anchors.centerIn: parent
            width: Math.max(28, parent.width * 0.6); height: width
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: map.hoverKey = "s" + st.modelData.key
            onExited: if (map.hoverKey === "s" + st.modelData.key) map.hoverKey = ""
            onClicked: if (st.picked && !flight.running) map.land(st.modelData); else map.select(st.modelData)
          }
        }
        // метка выбранной звезды: ромб
        Rectangle {
          visible: st.picked && orb.visible
          x: (st.p ? st.p.x : 0) - 12; y: (st.p ? st.p.y : 0) - 12
          width: 24; height: 24; rotation: 45
          color: "transparent"; antialiasing: true
          border.width: 1; border.color: map.acc
        }
        Column {
          // дикие подписаны только под курсором — иначе небо в надписях
          visible: orb.visible && !st.picked && (!st.wild || st.hov)
          x: (st.p ? st.p.x : 0) + orb.width * 0.3 + 6
          y: (st.p ? st.p.y : 0) - 8
          SpaceDecode {
            decode: false
            text: st.modelData.name + (st.here ? "  ◂" : "")
            color: st.here ? map.acc : map.fg
            opacity: st.hov ? 1 : 0.6
          }
          SpaceDecode {
            decode: false
            size: 10
            text: st.modelData.world && (st.wild || st.hov) ? st.modelData.world.title : map.appsOf(st.modelData)
            color: st.modelData.world && (st.wild || st.hov) ? st.modelData.world.color : map.a(map.fg, 0.5)
            visible: text !== "" && (st.here || st.hov)
          }
        }
      }
    }

    // планеты: снимок окна в шаре, тень терминатора, атмосфера
    Repeater {
      model: map.planets
      Item {
        id: pl
        required property var modelData
        required property int index
        readonly property var p: map.sel ? map.project(map.orbitPt(map.sel.pos, modelData.r, modelData.ang)) : null
        readonly property real grow: Math.max(0, Math.min(1, map.bloom * 1.5 - 0.1 * index))
        readonly property real rpx: p ? (homeWorld ? 1.7 : 1.25) * map.focal / p.z * grow : 0
        readonly property bool homeWorld: !!modelData.home
        readonly property var wworld: map.sel ? map.sel.world : null
        readonly property var ipc: modelData.t && modelData.t.lastIpcObject ? modelData.t.lastIpcObject : ({})
        readonly property real aspect: ipc.size && ipc.size[1] ? ipc.size[0] / ipc.size[1] : 1.6
        readonly property bool lit: map.hoverKey === String(index)
        visible: !!p && rpx > 1.5 && !map.landing
        z: 6 + (p ? 1 - Math.min(1, p.z / 400) : 0)
        x: (p ? p.x : 0) - rpx
        y: (p ? p.y : 0) - rpx
        width: rpx * 2; height: rpx * 2
        ClippingRectangle {
          anchors.fill: parent
          radius: width / 2
          color: pl.homeWorld && pl.wworld ? pl.wworld.bg : map.mixc(map.bg, map.acc, 0.25)
          // планета дикой системы — сам мир: его фон, акцент полосой атмосферы у горизонта (как небо его пейзажа)
          Rectangle {
            visible: pl.homeWorld && !!pl.wworld
            anchors.fill: parent
            gradient: Gradient {
              GradientStop { position: 0; color: pl.wworld ? pl.wworld.bg : "black" }
              GradientStop { position: 0.55; color: pl.wworld ? map.mixc(pl.wworld.color, pl.wworld.bg, 0.35) : "black" }
              GradientStop { position: 0.62; color: pl.wworld ? map.mixc(pl.wworld.bg, "#0e1528", 0.6) : "black" }
              GradientStop { position: 1; color: pl.wworld ? map.mixc(pl.wworld.bg, "#000000", 0.4) : "black" }
            }
          }
          ScreencopyView {
            visible: !pl.homeWorld
            anchors.centerIn: parent
            width: pl.aspect >= 1 ? parent.height * pl.aspect : parent.width
            height: pl.aspect >= 1 ? parent.height : parent.width / pl.aspect
            captureSource: pl.modelData.t ? pl.modelData.t.wayland : null
            live: false
            opacity: 0.9
          }
          // ночная сторона: свет — от звезды (центр экрана)
          Shape {
            anchors.fill: parent
            ShapePath {
              strokeColor: "transparent"
              fillGradient: RadialGradient {
                centerX: pl.width * 0.5 + (map.cx - pl.x - pl.width / 2 > 0 ? 1 : -1) * pl.width * 0.28; centerY: pl.height * 0.35
                centerRadius: pl.width * 0.95
                focalX: centerX; focalY: centerY
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.55; color: map.a(map.bg, 0.15) }
                GradientStop { position: 1; color: map.a(map.bg, 0.85) }
              }
              PathRectangle { x: 0; y: 0; width: pl.width; height: pl.height }
            }
          }
        }
        Rectangle {
          anchors.centerIn: parent
          width: parent.width + 6; height: width; radius: width / 2
          color: "transparent"
          border.width: 1
          border.color: pl.homeWorld && pl.wworld ? map.a(pl.wworld.color, pl.lit ? 0.9 : 0.5) : map.a(pl.lit ? map.acc : map.fg, pl.lit ? 0.8 : 0.22)
        }
        Rectangle {
          visible: pl.lit
          anchors.centerIn: parent
          width: parent.width + 18; height: width; rotation: 45
          color: "transparent"; antialiasing: true
          border.width: 1; border.color: map.acc
        }
        SpaceDecode {
          visible: pl.lit
          x: parent.width + 14; y: parent.height / 2 - height / 2
          decode: false
          size: 10
          text: pl.homeWorld ? (pl.wworld ? pl.wworld.title : "") : map.appOf(pl.modelData.t)
          color: pl.homeWorld && pl.wworld ? pl.wworld.color : map.acc
        }
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: map.hoverKey = String(pl.index)
          onExited: if (map.hoverKey === String(pl.index)) map.hoverKey = ""
          onClicked: if (pl.homeWorld) map.land(map.sel); else map.focusWindow(pl.modelData.t)
        }
      }
    }

    // звёзды за краем экрана: ромб на краю с номером (только столы — дикие не подписываются)
    Repeater {
      model: map.used
      Item {
        id: mk
        required property var modelData
        readonly property var q: map.rel(modelData.pos)
        readonly property var p: map.project(modelData.pos)
        readonly property bool off: !p || p.x < 40 || p.y < 40 || p.x > map.width - 40 || p.y > map.height - 40
        readonly property real ang: Math.atan2(-q[1], q[0])
        readonly property real k: Math.min((map.width / 2 - 36) / Math.max(1e-3, Math.abs(Math.cos(ang))),
                                           (map.height / 2 - 36) / Math.max(1e-3, Math.abs(Math.sin(ang))))
        readonly property bool here: modelData.kind === "ws" && modelData.id === map.current
        visible: off && !flight.running
        x: map.cx + Math.cos(ang) * k
        y: map.cy + Math.sin(ang) * k
        z: 11
        Rectangle { anchors.centerIn: parent; width: 6; height: 6; rotation: 45; antialiasing: true; color: mk.here ? map.acc : map.fg }
        SpaceDecode {
          x: -Math.cos(mk.ang) * 20 - width / 2
          y: -Math.sin(mk.ang) * 14 - height / 2
          decode: false
          size: 9
          text: mk.modelData.special !== "" ? mk.modelData.special : map.pad(mk.modelData.id)
          color: mk.here ? map.acc : map.a(map.fg, 0.55)
        }
        MouseArea { anchors.centerIn: parent; width: 24; height: 24; cursorShape: Qt.PointingHandCursor; onClicked: map.select(mk.modelData) }
      }
    }

    // карточка выбранной системы — плашка HUD: срезанный угол, черта акцентом (у него — рядом с объектом)
    Item {
      id: cardBox
      readonly property var p: map.sel ? map.project(map.sel.pos) : null
      visible: !!p && !map.landing
      opacity: flight.running ? 0 : 1
      Behavior on opacity { NumberAnimation { duration: 260 } }
      // показание HUD в левом верхнем углу — не закрывает орбиты
      x: 56
      y: 72
      z: 10
      Shape {
        id: cardBg
        width: card.width; height: card.height
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeWidth: 1
          strokeColor: map.a(map.acc, 0.35)
          fillColor: map.a(map.bg, 0.72)
          startX: 12; startY: 0
          PathLine { x: card.width; y: 0 }
          PathLine { x: card.width; y: card.height }
          PathLine { x: 0; y: card.height }
          PathLine { x: 0; y: 12 }
          PathLine { x: 12; y: 0 }
        }
      }
      Rectangle { x: 0; y: 12; width: 2; height: card.height - 12; color: map.acc }
      Item {
        id: card
        width: 270
        height: info.height + 24
        Column {
          id: info
          readonly property var s: map.sel
          readonly property bool wild: !!s && s.kind === "wild"
          readonly property var wins: s && s.ws ? s.ws.toplevels.values : []
          x: 16; y: 12
          width: parent.width - 30
          spacing: 5
          SpaceDecode {
            size: 12
            color: map.fg
            text: info.s ? info.s.name + (info.s.special === "" && info.s.id === map.current ? "  (you)" : "") : ""
          }
          SpaceDecode {
            color: map.acc
            text: !info.s ? "" : info.wild ? "1 planet // unexplored"
              : (info.s.special !== "" ? "scratchpad // " : "") + (info.wins.length === 0 ? "no planets" : info.wins.length + (info.wins.length === 1 ? " planet" : " planets"))
          }
          // мир системы: у дикой — куда перекрасит посадка, у занятой — запомненный
          SpaceDecode {
            visible: !!info.s && !!info.s.world
            size: 10
            text: info.s && info.s.world ? "world // " + info.s.world.title : ""
            color: info.s && info.s.world ? info.s.world.color : map.fg
          }
          Repeater {
            model: info.wins.slice(0, 8)
            SpaceDecode {
              required property var modelData
              required property int index
              caps: false
              decode: false
              size: 11
              width: info.width
              clip: true
              text: "◦ " + (map.appOf(modelData) || "window") + (modelData.title ? "  " + modelData.title : "")
              color: map.hoverKey === String(index) ? map.acc : map.a(map.fg, 0.55)
            }
          }
          Item {
            width: info.width; height: hint.height + 4
            SpaceDecode { id: hint; y: 4; decode: false; size: 9; color: map.a(map.fg, 0.4); text: info.wild ? "enter  land  //  new world" : "enter  land    click planet  focus" }
          }
        }
      }
    }

    SpaceDecode {
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottomMargin: 26
      decode: false
      text: "hjkl wasd  pick    tab  next system    enter  land    1-9  jump    r  new galaxy    wheel  zoom    esc  back"
      color: map.a(map.fg, 0.45)
    }
  }

  property string hoverKey: ""

  Item {
    anchors.fill: parent
    focus: true
    Keys.onPressed: function(e) {
      var t = e.text.toLowerCase()
      if (e.key === Qt.Key_Escape) map.close()
      else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) map.land(map.sel)
      else if (e.key === Qt.Key_Backtab) map.step(-1)
      else if (e.key === Qt.Key_Tab) map.step(1)
      else if (t === "r") map.newGalaxy()
      else if (e.key === Qt.Key_Left || t === "h" || t === "a") map.pickDir(-1, 0)
      else if (e.key === Qt.Key_Right || t === "l" || t === "d") map.pickDir(1, 0)
      else if (e.key === Qt.Key_Up || t === "k" || t === "w") map.pickDir(0, -1)
      else if (e.key === Qt.Key_Down || t === "j" || t === "s") map.pickDir(0, 1)
      else if (t >= "1" && t <= "9") {
        var s = map.sysByKey("ws" + t)
        if (s) map.land(s)
        else { map.landing = true; map.landAction = function() { map.hl("hl.dispatch(hl.dsp.focus({ workspace = '" + t + "' }))") }; landAnim.restart() }
      }
      else return
      e.accepted = true
    }
  }
}

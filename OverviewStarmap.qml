import QtQuick
import QtQuick.Shapes
import QtQuick.Window
import QtQuick3D
import QtQuick3D.Helpers
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

// Звёздная карта — обзор столов райса Space в настоящем 3D (Qt Quick 3D). По мотивам Space/overview/Overview.qml из
// github.com/elifouts/Dotfiles (GPL-3.0): небо — его overview.frag, миры — его World.themes; код карты свой.
//
// Два уровня, всегда видно, где ты (строка вверху: GALAXY › SYSTEM 03):
//  • ГАЛАКТИКА. Диск под углом. Ядро — твои столы: звёзды с номерами, трасса 01→02→03, точки вокруг — окна, текущий
//    стол — «YOU ARE HERE». Special-столы — малые звёзды у ядра. За пунктирной границей UNCHARTED — пояс неизведанных
//    систем цвета своего мира (одна из его девяти палитр + акцент); карточка показывает снимок пейзажа и палитру.
//  • СИСТЕМА (Enter / двойной клик). Камера влетает к звезде: окна — 3D-планеты со снимком окна, на наклонных орбитах;
//    у неизведанной — планеты в цветах мира, обитаемая — с пейзажем. Enter — сесть (у неизведанной — колонизировать:
//    свободный стол получает этот мир, omarchy-space-world), Esc — назад в галактику.
// Управление (F — переключить):
//  • ROUTE: ←/→ h/l — по трассе (в поясе — по кольцу), ↑/↓ k/j — в пояс / в ядро; у звёзд, куда уведут клавиши, —
//    стрелки ◂ ▸ ▴ ▾. На уровне системы ←/→ — планеты. Tab — следующий стол, 1–9 — сразу на стол.
//  • FREE (как у него): WASD — полёт с инерцией, Shift — быстрее, Q/E — вниз/вверх, мышь с зажатой кнопкой — обзор;
//    звезда в прицеле подсвечивается, Enter — влететь.
//  Мышь в обоих: тянуть — вращать, колесо — ближе/дальше, клик — выбрать, двойной клик — влететь.
// Экономия: View3D рисует только при изменениях (в покое 0 кадров), на движении — в 0.6 разрешения; свечение сцены
// выключено (ореолы — 2D-орбы), вращение планет — по желанию (starmapSpin); снимки окон — по одному кадру.
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
  function a(c, k) { c = Qt.color(c); return Qt.rgba(c.r, c.g, c.b, k) }
  function mixc(x, y, k) { x = Qt.color(x); y = Qt.color(y); return Qt.rgba(x.r + (y.r - x.r) * k, x.g + (y.g - x.g) * k, x.b + (y.b - x.b) * k, 1) }
  function pad(n) { return (n < 10 ? "0" : "") + n }
  function r3(x, y, z) { var v = Math.sin(x * 12.9898 + y * 78.233 + z * 37.719) * 43758.5453; return v - Math.floor(v) }
  function v3(p) { return Qt.vector3d(p[0], p[1], p[2]) }

  // ── миры, память столов ───────────────────────────────────────────────────────────────────────────────────────
  readonly property string home: Quickshell.env("HOME")
  property var worlds: []    // omarchy-space-world --list
  property var stored: ({})  // стол → {theme, acc, seed}: мир, полученный колонизацией
  property var taken: []     // ключи колонизированных звёзд пояса
  property int galaxy: 1     // сид пояса (R — новая галактика)
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
    onLoaded: {
      try { var d = JSON.parse(text() || "{}"); map.stored = d.stars || {}; map.taken = d.taken || []; map.galaxy = d.galaxy || 1 } catch (e) {}
    }
  }
  function saveStars() { starsFile.setText(JSON.stringify({ galaxy: galaxy, stars: stored, taken: taken }, null, 1)) }
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

  // ── системы ───────────────────────────────────────────────────────────────────────────────────────────────────
  readonly property var monitor: Hyprland.monitorFor(screen)
  readonly property int current: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : 1
  readonly property real borderR: 430
  readonly property real beltR: 600
  // ядро — его спираль World.starOf
  function starOf(id) { var t = id * 2.4, r = 60 + id * 22; return [Math.cos(t) * r, Math.sin(id * 1.3) * 26, Math.sin(t) * r] }
  function specialPos(name) {
    var h = 7
    for (var i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) | 0
    var t = r3(h, 1, 2) * Math.PI * 2, r = 120 + r3(h, 3, 4) * 120
    return [Math.cos(t) * r, (r3(h, 5, 6) - 0.5) * 50, Math.sin(t) * r]
  }
  readonly property var core: {
    var list = Hyprland.workspaces.values, ws = [], sp = []
    for (var i = 0; i < list.length; i++) {
      var w = list[i]
      if (w.id > 0) {
        var st = stored[String(w.id)] || null
        ws.push({ key: "ws" + w.id, kind: "ws", id: w.id, name: "system " + pad(w.id), label: pad(w.id), ws: w,
                  pos: starOf(w.id), world: st ? worldOf(st.theme, st.acc) : null, st: st, r: 9, special: "" })
      } else if (String(w.name).indexOf("special:") === 0 && w.toplevels.values.length > 0) {
        var n = String(w.name).slice(8)
        sp.push({ key: "sp" + n, kind: "special", id: w.id, name: n, label: n, ws: w, special: n, pos: specialPos(w.name),
                  world: null, st: null, r: 5 })
      }
    }
    ws.sort(function(x, y) { return x.id - y.id })
    return ws.concat(sp)
  }
  // пояс неизведанного: 16 звёзд по кольцу, мир — хэш галактики; колонизированные исчезают
  readonly property var belt: {
    if (!worlds.length) return []
    var out = [], g = galaxy * 101, n = 16
    for (var i = 0; i < n; i++) {
      var key = "w" + galaxy + ":" + i
      if (taken.indexOf(key) >= 0) continue
      var t = (i + 0.2 + 0.6 * r3(i, g, 3)) / n * Math.PI * 2, r = beltR + (r3(i, g, 5) - 0.5) * 160
      var k = Math.floor(r3(i, g, 9) * worlds.length), w = worlds[k]
      if (curWorld && w.theme === curWorld.theme && w.acc === curWorld.acc) w = worlds[(k + 7) % worlds.length]
      out.push({ key: key, kind: "wild", id: -1, name: "uncharted", label: "", ws: null, ang: t, special: "",
                 pos: [Math.cos(t) * r, (r3(i, g, 7) - 0.5) * 60, Math.sin(t) * r], world: w,
                 seed: 1 + Math.floor(r3(i, g, 2) * 996), r: 7 })
    }
    return out
  }
  readonly property var systems: core.concat(belt)
  function sysByKey(k) { for (var i = 0; i < systems.length; i++) if (systems[i].key === k) return systems[i]; return null }
  property string selKey: "ws" + current
  readonly property var sel: sysByKey(selKey) || (core.length ? core[0] : null)
  function appOf(t) { var o = t && t.lastIpcObject; var c = String(o && o.class ? o.class : (t && t.title ? t.title : "")); return c.split(".").pop() }
  function winsOf(s) { return s && s.ws ? s.ws.toplevels.values : [] }

  // ── уровень и камера ──────────────────────────────────────────────────────────────────────────────────────────
  property string level: "galaxy"        // galaxy | system
  property string sysKey: ""
  readonly property var sys: level === "system" ? sysByKey(sysKey) : null
  property real sysFade: 0               // 0 — галактика, 1 — система (подписи и планеты)
  Behavior on sysFade { NumberAnimation { duration: 700; easing.type: Easing.InOutCubic } }
  property string nav: "route"           // route | free (начальный — starmapNav, F переключает)

  readonly property real fov: 50
  readonly property real focal: (height / 2) / Math.tan(fov / 2 * Math.PI / 180)
  // орбитальная камера: цель, рыскание, тангаж (вниз — минус), расстояние
  property var tgt: [0, 0, 0]
  property real yaw: 0
  property real pitch: -0.62
  property real dist: 1050
  // свободная камера
  property var pos: [0, 0, 0]
  // базис камеры для проекции подписей: C, r, u, f
  property var cam: ({ c: [0, 0, 1000], r: [1, 0, 0], u: [0, 1, 0], f: [0, 0, -1] })
  function norm(v) { var l = Math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]) || 1; return [v[0] / l, v[1] / l, v[2] / l] }
  function cross(a, b) { return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]] }
  function fwdOf(yw, pt) { return [-Math.sin(yw) * Math.cos(pt), Math.sin(pt), -Math.cos(yw) * Math.cos(pt)] }
  function applyCam() {
    var f = fwdOf(yaw, pitch), c
    if (nav === "free" && level === "galaxy") c = pos
    else c = [tgt[0] - f[0] * dist, tgt[1] - f[1] * dist, tgt[2] - f[2] * dist]
    var r = norm(cross(f, [0, 1, 0])), u = cross(r, f)
    camera.position = v3(c)
    camera.lookAt(Qt.vector3d(c[0] + f[0], c[1] + f[1], c[2] + f[2]))
    cam = { c: c, r: r, u: u, f: f }
  }
  function project(p) {
    var C = cam.c, q = [p[0] - C[0], p[1] - C[1], p[2] - C[2]]
    var z = q[0] * cam.f[0] + q[1] * cam.f[1] + q[2] * cam.f[2]
    if (z < 2) return null
    var x = q[0] * cam.r[0] + q[1] * cam.r[1] + q[2] * cam.r[2], y = q[0] * cam.u[0] + q[1] * cam.u[1] + q[2] * cam.u[2]
    return { x: width / 2 + x / z * focal, y: height / 2 - y / z * focal, z: z, k: focal / z }
  }

  // перелёт: цель/рыскание/тангаж/расстояние от «было» к «станет»
  property var from: ({ t: [0, 0, 0], yaw: 0, pitch: -0.6, dist: 1000 })
  property var to: ({ t: [0, 0, 0], yaw: 0, pitch: -0.6, dist: 1000 })
  property real flyT: 1
  function fly(t, yw, pt, d, ms) {
    while (yw - yaw > Math.PI) yw -= Math.PI * 2
    while (yw - yaw < -Math.PI) yw += Math.PI * 2
    from = { t: tgt, yaw: yaw, pitch: pitch, dist: dist }
    to = { t: t, yaw: yw, pitch: pt, dist: d }
    flight.duration = ms
    flight.restart()
  }
  NumberAnimation {
    id: flight; target: map; property: "flyT"; from: 0; to: 1; duration: 900
    // начальный режим FREE — после взлёта
    onFinished: if (map.startFree) { map.startFree = false; map.setNav("free") }
  }
  property bool startFree: host.value("starmapNav") === "free"
  onFlyTChanged: {
    var k = flyT, e = k < 0.5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2, F = from, T = to
    tgt = [F.t[0] + (T.t[0] - F.t[0]) * e, F.t[1] + (T.t[1] - F.t[1]) * e, F.t[2] + (T.t[2] - F.t[2]) * e]
    yaw = F.yaw + (T.yaw - F.yaw) * e
    pitch = F.pitch + (T.pitch - F.pitch) * e
    dist = F.dist + (T.dist - F.dist) * e
    applyCam()
  }
  property bool dragging: false
  readonly property bool moving: flight.running || dragging || freeMove.running || landAnim.running

  // вид галактики: камера над диском со стороны текущего стола
  function yawFor(p) { return Math.atan2(p[0], p[2]) }
  function galaxyView(ms) {
    var s = sysByKey("ws" + current)
    fly([0, 0, 0], s ? yawFor(s.pos) : 0, -0.62, 1050, ms)
  }
  function sysDist(s) { var n = s.kind === "wild" ? 4 : Math.max(1, winsOf(s).length); return 70 + (22 + Math.min(9, n) * 10) * 1.25 }
  function enterSystem(s) {
    if (!s || landing) return
    selKey = s.key
    sysKey = s.key
    if (nav === "free") {
      // свободная камера → орбитальная вокруг того, что впереди
      tgt = [cam.c[0] + cam.f[0] * 300, cam.c[1] + cam.f[1] * 300, cam.c[2] + cam.f[2] * 300]; dist = 300
    }
    level = "system"
    sysFade = 1
    planetSel = -1
    fly(s.pos, yaw, -0.42, sysDist(s), 1000)
    if (s.kind === "wild") previews.want(s)
  }
  function exitSystem() {
    level = "galaxy"
    sysFade = 0
    if (nav === "free") { var f = fwdOf(yaw, pitch); pos = [tgt[0] - f[0] * 260, tgt[1] - f[1] * 260 + 60, tgt[2] - f[2] * 260]; applyCam() }
    else galaxyView(1000)
  }
  // в галактике выбор не двигает камеру; только если звезда ушла за край — доворот
  function select(s) {
    if (!s || landing) return
    selKey = s.key
    if (s.kind === "wild") previews.want(s)
    if (level !== "galaxy" || nav !== "route") return
    var p = project(s.pos)
    if (!p || p.x < 120 || p.x > width - 120 || p.y < 120 || p.y > height - 120) fly([0, 0, 0], yawFor(s.pos), pitch, dist, 700)
  }

  // ── маршрут (ROUTE): куда уведут стрелки ────────────────────────────────────────────────────────────────────────
  readonly property var lane: core
  // объекты из property var при чтении копируются — сравнивать только по key
  function idxOf(list, s) { if (!s) return -1; for (var i = 0; i < list.length; i++) if (list[i].key === s.key) return i; return -1 }
  function laneStep(d) {
    if (!sel) return null
    if (sel.kind === "wild") {
      if (!belt.length) return null
      var b = belt.slice().sort(function(x, y) { return x.ang - y.ang }), i = idxOf(b, sel)
      return b[(i + d + b.length) % b.length]
    }
    var j = idxOf(lane, sel)
    return lane.length ? lane[(j + d + lane.length) % lane.length] : null
  }
  function angOf(p) { return Math.atan2(p[2], p[0]) }
  function nearestByAngle(list, p) {
    var best = null, bd = 9, a0 = angOf(p)
    for (var i = 0; i < list.length; i++) {
      var d = Math.abs(angOf(list[i].pos) - a0); d = Math.min(d, Math.PI * 2 - d)
      if (d < bd) { bd = d; best = list[i] }
    }
    return best
  }
  readonly property var navTargets: {
    if (!sel || level !== "galaxy") return ({})
    var o = { left: laneStep(-1), right: laneStep(1) }
    if (sel.kind === "wild") o.down = nearestByAngle(core.filter(function(s) { return s.kind === "ws" }), sel.pos)
    else o.up = nearestByAngle(belt, sel.pos)
    return o
  }
  readonly property var navKeys: {
    var o = navTargets, k = {}
    for (var d in o) if (o[d]) k[o[d].key] = d
    return k
  }

  // ── посадка ───────────────────────────────────────────────────────────────────────────────────────────────────
  property bool landing: false
  property var landAction: null
  function hl(lua) { Quickshell.execDetached(["hyprctl", "eval", lua]) }
  function freeWs() {
    var ids = Hyprland.workspaces.values.map(function(w) { return w.id })
    for (var i = 1; i <= 10; i++) if (ids.indexOf(i) < 0 && !stored[String(i)]) return i
    for (i = 1; i <= 10; i++) if (ids.indexOf(i) < 0) return i
    return 10
  }
  function applyWorld(st, id) { Quickshell.execDetached(["omarchy-space-world", st.theme, String(st.acc), String(st.seed), String(id)]) }
  function land(s, win) {
    if (!s || landing) return
    landing = true
    if (win) {
      var addr = win.lastIpcObject ? String(win.lastIpcObject.address || "") : ""
      landAction = function() {
        if (s.special) map.hl("hl.dispatch(hl.dsp.workspace.toggle_special('" + s.special + "'))")
        if (addr) map.hl("hl.dispatch(hl.dsp.focus({ window = 'address:" + addr + "' }))")
      }
    } else if (s.kind === "wild") {
      var id = freeWs(), st = { theme: s.world.theme, acc: s.world.acc, seed: s.seed }
      var next = Object.assign({}, stored); next[String(id)] = st; stored = next
      taken = taken.concat([s.key])
      saveStars()
      landAction = function() { map.hl("hl.dispatch(hl.dsp.focus({ workspace = '" + id + "' }))"); map.applyWorld(st, id) }
    } else if (s.kind === "special") {
      landAction = function() { map.hl("hl.dispatch(hl.dsp.workspace.toggle_special('" + s.special + "'))") }
    } else {
      var keep = s.st && !sameWorld(s.st) ? s.st : null
      landAction = function() { map.hl("hl.dispatch(hl.dsp.focus({ workspace = '" + s.id + "' }))"); if (keep) map.applyWorld(keep, s.id) }
    }
    if (nav === "free" && level === "galaxy") {
      nav = "route"
      tgt = [cam.c[0] + cam.f[0] * 200, cam.c[1] + cam.f[1] * 200, cam.c[2] + cam.f[2] * 200]; dist = 200
    }
    fly(s.pos, yaw, pitch, 6, 650)
    landAnim.restart()
  }
  function jump(id) {
    var s = sysByKey("ws" + id)
    if (s) { land(s); return }
    landing = true
    landAction = function() { map.hl("hl.dispatch(hl.dsp.focus({ workspace = '" + id + "' }))") }
    landAnim.restart()
  }
  function close() { if (landing) return; landing = true; landAction = null; landAnim.restart() }
  property real ui: 0
  NumberAnimation { id: uiIn; target: map; property: "ui"; from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic }
  SequentialAnimation {
    id: landAnim
    PauseAnimation { duration: 300 }
    ScriptAction { script: if (map.landAction) map.landAction() }
    NumberAnimation { target: map; property: "ui"; to: 0; duration: 320; easing.type: Easing.InCubic }
    ScriptAction { script: map.host.overviewOpen = false }
  }

  // ── превью миров (снимок пейзажа в кэше; не больше одного процесса за раз) ────────────────────────────────────────
  QtObject {
    id: previews
    property var urls: ({})
    property var queue: []
    function key(s) { return s.world.theme + "-" + s.world.acc + "-" + s.seed }
    function want(s) {
      if (!s || s.kind !== "wild" || !s.world) return
      var k = key(s)
      if (urls[k] !== undefined || queue.indexOf(k) >= 0) return
      queue = queue.concat([k])
      pump()
    }
    function pump() {
      if (prevProc.running || !queue.length) return
      var k = queue[0], p = k.split("-")
      prevProc.k = k
      prevProc.command = ["omarchy-space-world", "--preview", p[0], p[1], p[2]]
      prevProc.running = true
    }
  }
  Process {
    id: prevProc
    property string k: ""
    stdout: StdioCollector {
      onStreamFinished: {
        var u = Object.assign({}, previews.urls), t = text.trim()
        u[prevProc.k] = t ? "file://" + t : ""
        previews.urls = u
        previews.queue = previews.queue.slice(1)
        Qt.callLater(previews.pump)
      }
    }
  }
  function previewOf(s) { return s && s.kind === "wild" && s.world ? (previews.urls[previews.key(s)] || "") : "" }

  // ── старт ─────────────────────────────────────────────────────────────────────────────────────────────────────
  Component.onCompleted: {
    Hyprland.refreshToplevels()
    var s = sysByKey("ws" + current)
    // взлёт: камера стоит у звезды текущего стола и поднимается над галактикой
    tgt = s ? s.pos : [0, 0, 0]; yaw = s ? yawFor(s.pos) : 0; pitch = -1.2; dist = 40
    applyCam()
    galaxyView(1100)
    uiIn.start()

  }

  // ── небо (его overview.frag) за прозрачным View3D ─────────────────────────────────────────────────────────────
  ShaderEffect {
    anchors.fill: parent
    opacity: map.ui
    readonly property real yaw: Math.atan2(-map.cam.f[0], -map.cam.f[2])
    readonly property real pitch: Math.asin(Math.max(-1, Math.min(1, map.cam.f[1])))
    readonly property real focal: map.focal
    readonly property real offX: -width / 2
    readonly property real offY: -height / 2
    readonly property real sizeW: width
    readonly property real sizeH: height
    readonly property color tint1: map.acc
    readonly property color tint2: map.mixc(map.acc, map.fg, 0.45)
    readonly property color base: map.mixc(map.bg, "#000000", 0.7)
    fragmentShader: Qt.resolvedUrl("shaders/starmap.frag.qsb")
  }

  // ── ореолы звёзд (его orb.frag) — под 3D: планеты перед звездой закрывают ореол ──────────────────────────────────
  Item {
    anchors.fill: parent
    opacity: map.ui
    Repeater {
      model: map.systems
      ShaderEffect {
        id: halo
        required property var modelData
        readonly property var p: map.project(modelData.pos)
        readonly property bool inSys: !!map.sys && map.sys.key === modelData.key
        readonly property bool wild: modelData.kind === "wild"
        readonly property bool picked: map.sel && map.sel.key === modelData.key
        // на уровне системы чужие звёзды — тихие точки, своя — мягкая корона
        readonly property real k: (wild && !picked ? 0.6 : 1) * (1 - map.sysFade * (inSys ? 0.2 : 0.7))
        visible: !!p && k > 0.05
        width: p ? Math.max(18, modelData.r * p.k * (inSys ? 5 : 7)) * (picked && !map.sys ? 1.3 : 1) : 0
        height: width
        x: p ? p.x - width / 2 : 0
        y: p ? p.y - height / 2 : 0
        opacity: k
        readonly property color tint: modelData.world ? map.mixc("#ffffff", modelData.world.color, 0.65)
          : modelData.kind === "special" ? map.mixc("#ffffff", map.acc, 0.7) : map.mixc("#ffe2b8", map.acc, 0.25)
        readonly property real core: 0.06  // не 0: шейдер делит на core (NaN — чёрное пятно)
        readonly property real glow: 1
        readonly property real shade: 0
        fragmentShader: Qt.resolvedUrl("shaders/orb.frag.qsb")
      }
    }
  }

  // ── 3D ────────────────────────────────────────────────────────────────────────────────────────────────────────
  property real screenDpr: Screen.devicePixelRatio
  View3D {
    id: view
    anchors.fill: parent
    opacity: map.ui
    renderMode: View3D.Offscreen
    explicitTextureWidth: map.moving ? Math.ceil(width * map.screenDpr * 0.6) : 0
    explicitTextureHeight: map.moving ? Math.ceil(height * map.screenDpr * 0.6) : 0
    // без свечения сцены: с прозрачным фоном оно размывает и белит всё (планеты); ореолы звёзд — 2D-слой ниже
    environment: SceneEnvironment {
      backgroundMode: SceneEnvironment.Transparent
      antialiasingMode: SceneEnvironment.MSAA
      antialiasingQuality: SceneEnvironment.Medium
    }
    PerspectiveCamera { id: camera; fieldOfView: map.fov; clipNear: 1; clipFar: 8000 }
    DirectionalLight { eulerRotation.x: -35; eulerRotation.y: 30; brightness: 0.12 }
    PointLight {
      visible: !!map.sys
      position: map.sys ? map.v3(map.sys.pos) : Qt.vector3d(0, 0, 0)
      brightness: 1.15
      color: map.sys && map.sys.world ? map.mixc("#ffffff", map.sys.world.color, 0.25) : "#fff4e6"
      quadraticFade: 0.0002
    }
    // далёкие звёзды — один draw call
    Model {
      source: "#Cube"
      // тусклые, ниже порога свечения — иначе их не отличить от систем
      scale: Qt.vector3d(0.014, 0.014, 0.014)
      instancing: RandomInstancing {
        instanceCount: 700
        randomSeed: 7
        position: InstanceRange { from: Qt.vector3d(-2600, -900, -2600); to: Qt.vector3d(2600, 900, 2600) }
        scale: InstanceRange { from: Qt.vector3d(0.6, 0.6, 0.6); to: Qt.vector3d(1.6, 1.6, 1.6); proportional: true }
        color: InstanceRange { from: "#262c3a"; to: "#6e7689" }
      }
      materials: PrincipledMaterial { lighting: PrincipledMaterial.NoLighting; baseColor: "white" }
    }
    // звёзды — светящиеся шары (glow), цвет — мир системы
    Repeater3D {
      model: map.systems
      Model {
        id: star
        required property var modelData
        readonly property bool picked: map.sel && map.sel.key === modelData.key
        readonly property bool wild: modelData.kind === "wild"
        readonly property bool inSys: !!map.sys && map.sys.key === modelData.key
        // на уровне системы: своя звезда — меньше и мягче (не забивает планеты), чужие — тусклые точки вдали
        readonly property real glowK: wild && !picked ? 0.75 : 1
        source: "#Sphere"
        position: map.v3(modelData.pos)
        readonly property real s: modelData.r / 50 * (picked && !map.sys ? 1.35 : 1) * (1 - map.sysFade * (inSys ? 0.4 : 0.6))
        scale: Qt.vector3d(s, s, s)
        materials: PrincipledMaterial {
          lighting: PrincipledMaterial.NoLighting
          baseColor: star.modelData.world ? map.mixc("#ffffff", star.modelData.world.color, star.wild ? 0.6 : 0.45)
            : star.modelData.kind === "special" ? map.mixc("#ffffff", map.acc, 0.6) : map.mixc("#fff1dc", map.acc, 0.2)
          emissiveFactor: Qt.vector3d(star.glowK, star.glowK, star.glowK)
        }
      }
    }
    // планеты системы
    Repeater3D {
      model: map.planets
      Node {
        id: pnode
        required property var modelData
        required property int index
        position: map.v3(modelData.p)
        readonly property real s: modelData.r / 50 * map.grow
        Model {
          source: "#Sphere"
          scale: Qt.vector3d(pnode.s, pnode.s, pnode.s)
          eulerRotation.y: map.spin * (12 + pnode.index * 3) + pnode.index * 40
          eulerRotation.z: 12
          materials: PrincipledMaterial {
            roughness: 0.85
            metalness: 0
            // окна полупрозрачные (прозрачность райса) — альфу снимка не учитываем, иначе шар белёсый
            alphaMode: PrincipledMaterial.Opaque
            baseColor: pnode.modelData.win || pnode.modelData.img !== "" ? "white" : pnode.modelData.color
            baseColorMap: pnode.modelData.win ? winTex : pnode.modelData.img !== "" ? imgTex : null
            emissiveFactor: Qt.vector3d(0.05, 0.05, 0.05)
          }
          Texture {
            id: winTex
            scaleU: 2
            tilingModeHorizontal: Texture.Repeat
            sourceItem: ScreencopyView {
              width: 640; height: 400
              captureSource: pnode.modelData.win ? pnode.modelData.win.wayland : null
              live: false
            }
          }
          Texture { id: imgTex; source: pnode.modelData.img; scaleU: 2; tilingModeHorizontal: Texture.Repeat }
        }
        // атмосфера выбранной / активной планеты
        Model {
          visible: pnode.modelData.lit || map.planetSel === pnode.index
          source: "#Sphere"
          readonly property real k: pnode.s * 1.14
          scale: Qt.vector3d(k, k, k)
          materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: map.a(map.acc, map.planetSel === pnode.index ? 0.25 : 0.12)
            alphaMode: PrincipledMaterial.Blend
            cullMode: Material.FrontFaceCulling
          }
        }
      }
    }
  }

  // ── планеты выбранной системы ─────────────────────────────────────────────────────────────────────────────────
  property real grow: sysFade
  property int planetSel: -1
  readonly property real tilt: sys ? 0.25 + r3(Math.round(sys.pos[0]), Math.round(sys.pos[2]), 2) * 0.3 : 0.3
  function orbitPt(c, r, t) { var z = Math.sin(t) * r; return [c[0] + Math.cos(t) * r, c[1] + z * Math.sin(tilt), c[2] + z * Math.cos(tilt)] }
  readonly property var planets: {
    var s = sys
    if (!s) return []
    var out = [], base = r3(s.pos[0], s.pos[2], 7) * Math.PI * 2, i, rr, ang
    if (s.kind === "wild") {
      var n = 2 + Math.floor(r3(s.seed, 3, 1) * 3), pal = s.world.palette
      for (i = 0; i < n; i++) {
        rr = 22 + i * 10; ang = base + i * 2.399
        out.push({ win: null, img: i === 0 ? map.previewOf(s) : "", r: i === 0 ? 7 : 3 + r3(s.seed, i, 4) * 3,
                   color: i === 0 ? pal[0] : pal[3 + Math.floor(r3(s.seed, i, 6) * 6)], orbit: rr, ang: ang, p: orbitPt(s.pos, rr, ang),
                   title: i === 0 ? s.world.title : "", lit: i === 0 })
      }
      return out
    }
    var ts = winsOf(s), mon = map.monitor, area = mon ? mon.width * mon.height : 1
    var act = Hyprland.activeToplevel
    for (i = 0; i < ts.length && i < 9; i++) {
      var o = ts[i].lastIpcObject || {}, sz = o.size || [800, 600]
      var r = 3 + 4 * Math.sqrt(Math.min(1, sz[0] * sz[1] / Math.max(1, area)))
      rr = 22 + i * 10; ang = base + i * 2.399
      out.push({ win: ts[i], img: "", r: r, color: map.mixc(map.bg, map.acc, 0.3), orbit: rr, ang: ang, p: orbitPt(s.pos, rr, ang),
                 title: map.appOf(ts[i]) + (ts[i].title ? "  " + ts[i].title : ""), lit: ts[i] === act })
    }
    return out
  }
  // вращение планет — по умолчанию выключено (starmapSpin): даже 30 шагов в секунду — это 30 кадров всего экрана,
  // Hyprland на них ~25 % видеокарты; в покое карта стоит ~3 %. Включено — шагами 30/с, только на уровне системы.
  property real spin: 0
  Timer {
    interval: 33
    repeat: true
    running: map.level === "system" && map.host.value("starmapSpin") === true && !map.landing
    onTriggered: map.spin += 0.033
  }

  // ── свободный полёт (FREE) ────────────────────────────────────────────────────────────────────────────────────
  property var held: ({})
  property var vel: [0, 0, 0]
  FrameAnimation {
    id: freeMove
    running: map.nav === "free" && map.level === "galaxy" && !map.landing
      && (Object.keys(map.held).length > 0 || Math.abs(map.vel[0]) + Math.abs(map.vel[1]) + Math.abs(map.vel[2]) > 0.05)
    onTriggered: {
      var dt = Math.min(0.05, frameTime), h = map.held, f = map.fwdOf(map.yaw, map.pitch)
      var r = map.norm(map.cross(f, [0, 1, 0])), acc = h.shift ? 900 : 320
      var ax = 0, ay = 0, az = 0
      if (h.w) { ax += f[0]; ay += f[1]; az += f[2] }
      if (h.s) { ax -= f[0]; ay -= f[1]; az -= f[2] }
      if (h.d) { ax += r[0]; az += r[2] }
      if (h.a) { ax -= r[0]; az -= r[2] }
      if (h.e) ay += 1
      if (h.q) ay -= 1
      var v = map.vel, damp = Math.pow(0.04, dt)
      v = [(v[0] + ax * acc * dt) * damp, (v[1] + ay * acc * dt) * damp, (v[2] + az * acc * dt) * damp]
      if (Object.keys(h).length === 0 && Math.abs(v[0]) + Math.abs(v[1]) + Math.abs(v[2]) < 0.5) v = [0, 0, 0]
      map.vel = v
      map.pos = [map.pos[0] + v[0] * dt, map.pos[1] + v[1] * dt, map.pos[2] + v[2] * dt]
      map.applyCam()
    }
  }
  function setNav(n) {
    if (n === nav || landing) return
    if (n === "free") {
      if (level === "system") exitSystem()
      pos = cam.c
      nav = "free"
      applyCam()
    } else {
      nav = "route"
      held = ({}); vel = [0, 0, 0]
      galaxyView(800)
    }
  }
  // прицел: звезда ближе всех к центру экрана
  readonly property var aimed: {
    if (nav !== "free" || level !== "galaxy") return null
    var best = null, bd = 46
    for (var i = 0; i < systems.length; i++) {
      var p = project(systems[i].pos)
      if (!p) continue
      var d = Math.hypot(p.x - width / 2, p.y - height / 2)
      if (d < bd) { bd = d; best = systems[i] }
    }
    return best
  }
  onAimedChanged: if (aimed) { selKey = aimed.key; if (aimed.kind === "wild") previews.want(aimed) }

  // ── 2D поверх 3D: трасса, граница, орбиты, подписи, подсказки ─────────────────────────────────────────────────
  property string hoverKey: ""
  Item {
    id: hud
    anchors.fill: parent
    opacity: map.ui

    // мышь: тянуть — вращать, колесо — ближе/дальше, правая — назад
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      property point last
      property bool moved: false
      onPressed: function(m) { last = Qt.point(m.x, m.y); moved = false }
      onPositionChanged: function(m) {
        var dx = m.x - last.x, dy = m.y - last.y
        if (!moved && Math.abs(dx) + Math.abs(dy) < 4) return
        moved = true; map.dragging = true
        last = Qt.point(m.x, m.y)
        if (flight.running) flight.stop()
        map.yaw -= dx * 0.005
        map.pitch = Math.max(-1.45, Math.min(map.nav === "free" && map.level === "galaxy" ? 1.4 : -0.08, map.pitch - dy * 0.004))
        map.applyCam()
      }
      onReleased: map.dragging = false
      onClicked: function(m) { if (!moved && m.button === Qt.RightButton) { if (map.level === "system") map.exitSystem(); else map.close() } }
      onWheel: function(w) {
        if (map.nav === "free" && map.level === "galaxy") {
          var f = map.fwdOf(map.yaw, map.pitch), d = w.angleDelta.y > 0 ? 40 : -40
          map.pos = [map.pos[0] + f[0] * d, map.pos[1] + f[1] * d, map.pos[2] + f[2] * d]
        } else {
          if (flight.running) flight.stop()
          var k = w.angleDelta.y > 0 ? 0.88 : 1.14
          map.dist = Math.max(map.level === "system" ? 40 : 300, Math.min(map.level === "system" ? 420 : 2200, map.dist * k))
        }
        map.applyCam()
      }
    }

    // граница UNCHARTED — пунктирное кольцо на диске
    Shape {
      anchors.fill: parent
      opacity: 1 - map.sysFade
      visible: opacity > 0.01
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeWidth: 1
        strokeColor: map.a(map.fg, 0.3)
        strokeStyle: ShapePath.DashLine
        dashPattern: [4, 6]
        fillColor: "transparent"
        PathMultiline { paths: map.ringPaths([0, 0, 0], map.borderR, 0, 96) }
      }
    }
    SpaceDecode {
      readonly property var pp: {
        var best = null
        for (var i = 0; i < 8; i++) {
          var t = i / 8 * Math.PI * 2, p = map.project([Math.cos(t) * map.borderR, 0, Math.sin(t) * map.borderR])
          if (p && (!best || p.y > best.y)) best = p
        }
        return best
      }
      visible: !!pp && map.sysFade < 0.5
      x: pp ? pp.x - width / 2 : 0
      y: pp ? pp.y + 8 : 0
      decode: false
      size: 10
      text: "uncharted  //  beyond this line"
      color: map.a(map.fg, 0.45)
    }
    // трасса столов
    Shape {
      anchors.fill: parent
      opacity: 1 - map.sysFade
      visible: opacity > 0.01
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeWidth: 1.5
        strokeColor: map.a(map.acc, 0.5)
        fillColor: "transparent"
        PathMultiline { paths: map.lanePaths() }
      }
    }
    // орбиты системы
    Shape {
      anchors.fill: parent
      opacity: map.sysFade
      visible: opacity > 0.01 && !!map.sys
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeWidth: 1
        strokeColor: map.a(map.fg, 0.22)
        fillColor: "transparent"
        PathMultiline { paths: map.orbitPaths() }
      }
    }

    // звёзды: подписи, окна точками, подсказки маршрута, клики
    Repeater {
      model: map.systems
      Item {
        id: st
        required property var modelData
        readonly property var p: map.project(modelData.pos)
        readonly property bool picked: map.sel && map.sel.key === modelData.key
        readonly property bool here: modelData.kind === "ws" && modelData.id === map.current
        readonly property bool wild: modelData.kind === "wild"
        readonly property bool inSys: !!map.sys && map.sys.key === modelData.key
        readonly property real rpx: p ? Math.max(6, modelData.r * p.k) : 0
        readonly property real gal: 1 - map.sysFade
        readonly property int nwin: map.winsOf(modelData).length
        visible: !!p && (gal > 0.02 || inSys)
        x: p ? p.x : 0
        y: p ? p.y : 0
        MouseArea {
          x: -Math.max(16, st.rpx); y: x; width: -2 * x; height: width
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: map.hoverKey = st.modelData.key
          onExited: if (map.hoverKey === st.modelData.key) map.hoverKey = ""
          onClicked: map.select(st.modelData)
          onDoubleClicked: { if (st.inSys) map.land(st.modelData); else map.enterSystem(st.modelData) }
        }
        // неизведанная — отметка сканера: тонкий ромб цвета её мира
        Rectangle {
          visible: st.wild && !st.picked && st.gal > 0.5
          width: st.rpx * 2 + 8; height: width; x: -width / 2; y: -height / 2; rotation: 45
          color: "transparent"; antialiasing: true
          border.width: 1; border.color: st.modelData.world ? map.a(st.modelData.world.color, 0.55) : map.a(map.fg, 0.3)
        }
        // выбранная — ромб, текущий стол — кольцо
        Rectangle {
          visible: st.picked && st.gal > 0.5
          width: st.rpx * 2 + 14; height: width; x: -width / 2; y: -height / 2; rotation: 45
          color: "transparent"; antialiasing: true
          border.width: 1; border.color: map.acc
        }
        Rectangle {
          visible: st.here && st.gal > 0.5
          width: st.rpx * 2 + 26; height: width; radius: width / 2; x: -width / 2; y: -height / 2
          color: "transparent"; border.width: 1; border.color: map.a(map.acc, 0.6)
        }
        // окна — точки вокруг звезды (галактика)
        Repeater {
          model: st.gal > 0.5 && !st.wild ? Math.min(6, st.nwin) : 0
          Rectangle {
            required property int index
            readonly property real t: index / Math.min(6, st.nwin) * Math.PI * 2 - 0.6
            x: Math.cos(t) * (st.rpx + 7) - 1.5; y: Math.sin(t) * (st.rpx + 7) * 0.55 - 1.5
            width: 3; height: 3; radius: 1.5
            color: map.a(map.fg, 0.75)
          }
        }
        // номер стола / имя
        Column {
          visible: st.gal > 0.5 && (!st.wild || st.picked || map.hoverKey === st.modelData.key)
          opacity: st.gal
          x: st.rpx + 10; y: -9
          spacing: 1
          SpaceDecode {
            decode: false
            size: st.modelData.kind === "ws" ? 13 : 10
            text: st.wild ? "uncharted" : st.modelData.label
            color: st.here ? map.acc : st.picked ? map.fg : map.a(map.fg, 0.75)
          }
          SpaceDecode {
            decode: false
            size: 9
            visible: text !== ""
            text: st.here ? "you are here" : st.modelData.world ? st.modelData.world.title : ""
            color: st.here ? map.a(map.acc, 0.8) : st.modelData.world ? st.modelData.world.color : map.fg
          }
        }
        // подсказки маршрута: куда уведёт клавиша
        Text {
          readonly property string d: map.nav === "route" ? (map.navKeys[st.modelData.key] || "") : ""
          readonly property string dir: d === "left" ? "◂ h" : d === "right" ? "l ▸" : d === "up" ? "▴ k" : d === "down" ? "▾ j" : ""
          visible: dir !== "" && st.gal > 0.5 && !st.picked
          text: dir
          x: -width / 2; y: st.rpx + 8
          font.family: map.mono; font.pixelSize: 11
          color: map.acc
        }
      }
    }

    // планеты: подписи и клики
    Repeater {
      model: map.planets
      Item {
        id: pl
        required property var modelData
        required property int index
        readonly property var p: map.project(modelData.p)
        readonly property real rpx: p ? modelData.r * map.grow * p.k : 0
        readonly property bool on: map.planetSel === index || map.hoverKey === "p" + index
        visible: !!p && map.sysFade > 0.5
        x: p ? p.x : 0
        y: p ? p.y : 0
        MouseArea {
          x: -Math.max(14, pl.rpx); y: x; width: -2 * x; height: width
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: map.hoverKey = "p" + pl.index
          onExited: if (map.hoverKey === "p" + pl.index) map.hoverKey = ""
          onClicked: map.land(map.sys, pl.modelData.win)
        }
        SpaceDecode {
          visible: pl.on || pl.modelData.lit
          x: pl.rpx + 10; y: -8
          decode: false; caps: false
          size: 11
          text: pl.modelData.title
          color: pl.on ? map.acc : map.a(map.fg, 0.7)
        }
      }
    }

    // прицел FREE
    Item {
      visible: map.nav === "free" && map.level === "galaxy"
      anchors.centerIn: parent
      Rectangle { anchors.centerIn: parent; width: 22; height: 22; radius: 11; color: "transparent"; border.width: 1; border.color: map.a(map.fg, 0.7) }
      Rectangle { anchors.centerIn: parent; width: 2; height: 2; radius: 1; color: map.fg }
    }

    // ── строка вверху: где ты и режим ──
    Row {
      x: 56; y: 34
      spacing: 10
      SpaceDecode { decode: false; size: 12; text: "galaxy"; color: map.level === "galaxy" ? map.fg : map.a(map.fg, 0.5) }
      SpaceDecode { decode: false; size: 12; visible: map.level === "system"; text: "›"; color: map.a(map.fg, 0.5) }
      SpaceDecode {
        decode: false; size: 12; visible: map.level === "system"
        text: map.sys ? (map.sys.kind === "wild" ? "uncharted // " + map.sys.world.title : map.sys.name) : ""
        color: map.sys && map.sys.world ? map.sys.world.color : map.fg
      }
      SpaceDecode {
        decode: false; size: 12; caps: false
        visible: map.level === "system" && map.planetSel >= 0 && map.planetSel < map.planets.length
        text: visible ? "›  " + map.planets[map.planetSel].title : ""
        color: map.acc
      }
    }
    Row {
      anchors.right: parent.right; anchors.rightMargin: 56; y: 34
      spacing: 8
      Repeater {
        model: ["route", "free"]
        Rectangle {
          required property string modelData
          width: lbl.implicitWidth + 16; height: 20
          color: map.nav === modelData ? map.a(map.acc, 0.22) : "transparent"
          border.width: 1; border.color: map.a(map.acc, map.nav === modelData ? 0.7 : 0.25)
          SpaceDecode { id: lbl; anchors.centerIn: parent; decode: false; size: 10; text: parent.modelData; color: map.fg }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: map.setNav(parent.modelData) }
        }
      }
      SpaceDecode { decode: false; size: 10; text: "f"; color: map.a(map.fg, 0.45); anchors.verticalCenter: parent.verticalCenter }
    }

    // ── карточка выбранной ──
    Item {
      id: cardBox
      x: 56; y: 70
      visible: !!info.s && !map.landing
      width: card.width; height: card.height
      Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeWidth: 1
          strokeColor: map.a(map.acc, 0.35)
          fillColor: map.a(map.bg, 0.78)
          startX: 12; startY: 0
          PathLine { x: card.width; y: 0 }
          PathLine { x: card.width; y: card.height }
          PathLine { x: 0; y: card.height }
          PathLine { x: 0; y: 12 }
          PathLine { x: 12; y: 0 }
        }
      }
      Rectangle { x: 0; y: 12; width: 2; height: card.height - 12; color: info.s && info.s.world ? info.s.world.color : map.acc }
      Item {
        id: card
        width: 290
        height: info.height + 26
        Column {
          id: info
          readonly property var s: map.level === "system" ? map.sys : map.sel
          readonly property bool wild: !!s && s.kind === "wild"
          readonly property var wins: map.winsOf(s)
          x: 16; y: 13
          width: parent.width - 30
          spacing: 6
          SpaceDecode {
            size: 13; color: map.fg
            text: !info.s ? "" : info.wild ? "uncharted system" : info.s.name + (info.s.kind === "ws" && info.s.id === map.current ? "  (you)" : "")
          }
          SpaceDecode {
            visible: !!info.s && !!info.s.world
            size: 10
            text: info.s && info.s.world ? "world // " + info.s.world.title : ""
            color: info.s && info.s.world ? info.s.world.color : map.fg
          }
          // снимок пейзажа и палитра мира
          Item {
            visible: info.wild
            width: info.width; height: visible ? 150 : 0
            Rectangle { anchors.fill: parent; color: info.wild ? info.s.world.bg : "black"; border.width: 1; border.color: map.a(map.fg, 0.15) }
            Image {
              anchors.fill: parent; anchors.margins: 1
              source: map.previewOf(info.s)
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
            }
            SpaceDecode { anchors.centerIn: parent; visible: map.previewOf(info.s) === ""; decode: false; size: 10; text: "scanning…"; color: map.a(map.fg, 0.5) }
          }
          Row {
            visible: info.wild
            spacing: 3
            Repeater {
              model: info.wild ? info.s.world.palette : []
              Rectangle { required property string modelData; width: 26; height: 10; color: modelData }
            }
          }
          SpaceDecode {
            visible: !info.wild
            color: map.acc
            text: !info.s ? "" : (info.s.kind === "special" ? "scratchpad // " : "") + (info.wins.length === 0 ? "no planets" : info.wins.length + (info.wins.length === 1 ? " planet" : " planets"))
          }
          Repeater {
            model: info.wild ? [] : info.wins.slice(0, 7)
            SpaceDecode {
              required property var modelData
              caps: false; decode: false; size: 11
              width: info.width; clip: true
              text: "◦ " + (map.appOf(modelData) || "window") + (modelData.title ? "  " + modelData.title : "")
              color: map.a(map.fg, 0.6)
            }
          }
          SpaceDecode {
            decode: false; size: 9
            color: map.a(map.fg, 0.45)
            text: map.level === "galaxy" ? "enter  —  " + (info.wild ? "approach system" : "enter system")
              : info.wild ? "enter  —  colonize: new workspace, new world" : "enter  —  land    click planet  —  focus"
          }
        }
      }
    }

    // нижняя строка клавиш — по режиму и уровню
    SpaceDecode {
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottomMargin: 26
      decode: false
      size: 10
      text: map.level === "system" ? "h l  planet    enter  " + (map.sys && map.sys.kind === "wild" ? "colonize" : "land") + "    drag  rotate    wheel  zoom    esc  galaxy"
        : map.nav === "route" ? "h l  along route    k j  uncharted / core    tab  next    enter  system    1-9  jump    r  new galaxy    f  free flight    esc  close"
        : "w a s d  fly    q e  down / up    shift  fast    drag  look    enter  aimed system    f  route    esc  close"
      color: map.a(map.fg, 0.45)
    }
  }

  // ── линии в проекции ──────────────────────────────────────────────────────────────────────────────────────────
  function ringPaths(c, r, tl, n) {
    var out = [], cur = []
    for (var i = 0; i <= n; i++) {
      var t = i / n * Math.PI * 2, z = Math.sin(t) * r
      var p = project([c[0] + Math.cos(t) * r, c[1] + z * Math.sin(tl), c[2] + z * Math.cos(tl)])
      if (p) cur.push(Qt.point(p.x, p.y))
      else if (cur.length) { if (cur.length > 1) out.push(cur); cur = [] }
    }
    if (cur.length > 1) out.push(cur)
    return out
  }
  function lanePaths() {
    var ws = core.filter(function(s) { return s.kind === "ws" }), out = [], cur = []
    for (var i = 0; i < ws.length; i++) {
      var p = project(ws[i].pos)
      if (p) cur.push(Qt.point(p.x, p.y))
      else if (cur.length) { if (cur.length > 1) out.push(cur); cur = [] }
    }
    if (cur.length > 1) out.push(cur)
    return out
  }
  function orbitPaths() {
    var s = sys
    if (!s) return []
    var out = []
    for (var i = 0; i < planets.length; i++) out = out.concat(ringPaths(s.pos, planets[i].orbit, tilt, 72))
    return out
  }

  // ── клавиатура ────────────────────────────────────────────────────────────────────────────────────────────────
  function keyName(e) {
    var t = e.text.toLowerCase()
    return e.key === Qt.Key_Shift ? "shift" : t.length === 1 && "wasdqe".indexOf(t) >= 0 ? t : ""
  }
  Item {
    anchors.fill: parent
    focus: true
    Keys.onReleased: function(e) {
      if (e.isAutoRepeat) return
      var k = map.keyName(e)
      if (k && map.held[k]) { var h = Object.assign({}, map.held); delete h[k]; map.held = h }
    }
    Keys.onPressed: function(e) {
      var t = e.text.toLowerCase()
      if (map.landing) { e.accepted = true; return }
      if (e.key === Qt.Key_Escape) { if (map.level === "system") map.exitSystem(); else map.close() }
      else if (t === "f") map.setNav(map.nav === "route" ? "free" : "route")
      else if (t >= "1" && t <= "9") map.jump(Number(t))
      else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) {
        if (map.level === "system") {
          var pls = map.planets, ps = map.planetSel >= 0 && map.planetSel < pls.length ? pls[map.planetSel] : null
          map.land(map.sys, ps && ps.win ? ps.win : null)
        } else map.enterSystem(map.nav === "free" ? map.aimed : map.sel)
      }
      else if (map.nav === "free" && map.level === "galaxy" && map.keyName(e) !== "") {
        if (!e.isAutoRepeat) { var h = Object.assign({}, map.held); h[map.keyName(e)] = true; map.held = h }
      }
      else if (map.level === "system") {
        var n = map.planets.length
        if (n && (e.key === Qt.Key_Left || t === "h")) map.planetSel = (map.planetSel - 1 + n) % n
        else if (n && (e.key === Qt.Key_Right || t === "l" || e.key === Qt.Key_Tab)) map.planetSel = (map.planetSel + 1) % n
        else return
      }
      else if (e.key === Qt.Key_Left || t === "h") map.select(map.navTargets.left)
      else if (e.key === Qt.Key_Right || t === "l") map.select(map.navTargets.right)
      else if (e.key === Qt.Key_Up || t === "k") map.select(map.navTargets.up)
      else if (e.key === Qt.Key_Down || t === "j") map.select(map.navTargets.down)
      else if (e.key === Qt.Key_Tab) { var i = map.idxOf(map.lane, map.sel); map.select(map.lane[(i + 1) % Math.max(1, map.lane.length)]) }
      else if (t === "r") { map.galaxy += 1; map.saveStars(); if (map.sel && map.sel.kind === "wild") map.selKey = "ws" + map.current }
      else return
      e.accepted = true
    }
  }
}

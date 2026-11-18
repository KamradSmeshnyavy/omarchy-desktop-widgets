pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Его Space/common/World.qml (github.com/elifouts/Dotfiles, GPL-3.0) для звёздной карты voyage. Мир — его девять
// палитр и акцент из них (hue — оттенок акцента), звёзды столов запоминаются (~/.local/state/omarchy/space-voyage.json,
// у нас ещё и сид земли пятым числом). Отличия от него:
//  • текущий мир берётся из темы Omarchy: space-world → current/theme/world.json (тема, акцент, сид), варианты Space —
//    по таблице, сид земли — из .scene.json текущих обоев; другая тема — оттенок акцента темы;
//  • reroll(h, s) — «мир сменился»: собрать и применить тему omarchy-space-world (у него — pywal-схема на лету);
//  • земля (рельеф, деревья…) — из .scene.json текущих обоев, а не из его настроек.
Singleton {
  id: root

  property real hue: 0.58
  property real seed: 17
  property real landSeed: 17
  readonly property var themes: [
    { id: "everforest", name: "everforest", c: ["#2d353b", "#d3c6aa", "#475258", "#e67e80", "#a7c080", "#dbbc7f", "#7fbbb3", "#d699b6", "#83c092"] },
    { id: "gruvbox", name: "gruvbox", c: ["#282828", "#ebdbb2", "#665c54", "#fb4934", "#b8bb26", "#fabd2f", "#83a598", "#d3869b", "#8ec07c"] },
    { id: "nord", name: "nord", c: ["#2e3440", "#d8dee9", "#4c566a", "#bf616a", "#a3be8c", "#ebcb8b", "#81a1c1", "#b48ead", "#88c0d0"] },
    { id: "catppuccin", name: "catppuccin", c: ["#24273a", "#cad3f5", "#5b6078", "#ed8796", "#a6da95", "#eed49f", "#8aadf4", "#c6a0f6", "#8bd5ca"] },
    { id: "tokyonight", name: "tokyo night", c: ["#24283b", "#c0caf5", "#565f89", "#f7768e", "#9ece6a", "#e0af68", "#7aa2f7", "#bb9af7", "#7dcfff"] },
    { id: "rosepine", name: "rosé pine", c: ["#191724", "#e0def4", "#524f67", "#eb6f92", "#9ccfd8", "#f6c177", "#31748f", "#c4a7e7", "#ebbcba"] },
    { id: "dracula", name: "dracula", c: ["#282a36", "#f8f8f2", "#6272a4", "#ff5555", "#50fa7b", "#f1fa8c", "#8be9fd", "#bd93f9", "#ff79c6"] },
    { id: "kanagawa", name: "kanagawa", c: ["#1f1f28", "#dcd7ba", "#54546d", "#e82424", "#98bb6c", "#e6c384", "#7e9cd8", "#957fb8", "#7aa89f"] },
    { id: "solarized", name: "solarized", c: ["#002b36", "#93a1a1", "#586e75", "#dc322f", "#859900", "#b58900", "#268bd2", "#6c71c4", "#2aa198"] }
  ]
  // варианты райса Space (omarchy-rices/space/build.py VARIANTS): тема → (палитра, акцент)
  readonly property var variants: ({ "space-dusk": ["dracula", 8], "space-mars": ["gruvbox", 3], "space-atlas": ["nord", 3], "space-frost": ["tokyonight", 8] })
  function accentHue(hex) { return Qt.color(hex).hslHue }
  property bool random: false
  property var pins: ({})
  property string curTheme: ""
  property var stars: ({})
  signal offersChanged()

  // ── память звёзд ──
  FileView {
    id: file
    path: Quickshell.env("HOME") + "/.local/state/omarchy/space-voyage.json"
    atomicWrites: true
    printErrors: false
    onLoaded: { try { const w = JSON.parse(text()); root.stars = w.stars ?? {}; root.pins = w.pins ?? ({}) } catch (e) {} }
  }
  function save() { file.setText(JSON.stringify({ stars: stars, pins: pins })) }
  function commit() {}

  // ── текущий мир — из темы Omarchy ──
  property string themeName: ""
  property var worldJson: null
  property var land: ({})
  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { root.themeName = text().trim(); root.sync() }
  }
  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/world.json"
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { try { root.worldJson = JSON.parse(text()) } catch (e) { root.worldJson = null } root.sync() }
    onLoadFailed: { root.worldJson = null; root.sync() }
  }
  // .scene.json рядом с текущими обоями: сид и параметры земли
  Process {
    id: bgProc
    command: ["readlink", "-f", Quickshell.env("HOME") + "/.local/state/omarchy/current/background"]
    running: true
    stdout: StdioCollector { onStreamFinished: { var p = text.trim(); scene.path = /\.(png|jpe?g|webp)$/i.test(p) ? p.replace(/\.[^.\/]+$/, ".scene.json") : "" } }
  }
  FileView {
    id: scene
    printErrors: false
    onLoaded: { try { const s = JSON.parse(text()); root.land = s.land || {}; if (s.seed !== undefined) root.landSeed = Number(s.seed); root.sync() } catch (e) {} }
  }
  function refresh() { bgProc.running = true }
  function landV(k, d) { const x = land ? land[k] : undefined; return x === undefined || x === null ? d : Number(x) }
  function sync() {
    let t = null, i = 0
    if (themeName === "space-world" && worldJson) { t = worldJson.theme; i = worldJson.acc; if (worldJson.seed !== undefined) landSeed = Number(worldJson.seed) }
    else if (variants[themeName]) { t = variants[themeName][0]; i = variants[themeName][1] }
    const th = themes.find(x => x.id === t)
    if (th) { hue = accentHue(th.c[i]); curTheme = th.id }
    else curTheme = ""
    seed = landSeed
    paint(hue)  // звезда текущего стола всегда в текущем мире
  }

  // ── его функции ──
  function offers() {
    const out = []
    for (const t of themes) {
      const p = pins[t.id]
      if (p !== undefined) out.push([t, p])
      else for (let i = 3; i < 9; i++) out.push([t, i])
    }
    return out
  }
  function snap(r, away) {
    const all = offers(), other = away ? all.filter(k => k[0].id !== curTheme) : all, a = other.length ? other : all
    if (random || a.length === 0) return r
    const k = a[Math.min(a.length - 1, Math.floor(r * a.length))]
    return accentHue(k[0].c[k[1]])
  }
  function nearest(h) {
    const a = offers()
    if (random || a.length === 0) return h
    let best = h, d = 9
    for (const k of a) {
      const v = accentHue(k[0].c[k[1]]), x = Math.abs(v - h), dd = Math.min(x, 1 - x)
      if (dd < d) { d = dd; best = v }
    }
    return best
  }
  function themeFor(h) {
    const list = themes.slice().sort((x, y) => (y.id === curTheme) - (x.id === curTheme))
    let best = null, bi = 3, d = 9
    for (const t of list) for (let i = 3; i < 9; i++) {
      const x = Math.abs(accentHue(t.c[i]) - h), dd = Math.min(x, 1 - x)
      if (dd < d - 1e-9) { d = dd; best = t; bi = i }
    }
    return d < 0.002 ? { t: best, i: bi } : null
  }
  readonly property var applied: random || !curTheme ? null : themeFor(hue)

  function starOf(id) {
    const s = stars[id]
    if (s) return s
    const a = id * 2.4
    return [Math.cos(a) * (60 + id * 22), Math.sin(id * 1.3) * 26, Math.sin(a) * (60 + id * 22), hue]
  }
  function place(id, pos, h, sd) {
    stars = Object.assign({}, stars, { [id]: [pos[0], pos[1], pos[2], h, sd ?? landSeed] })
    save()
  }
  // звезда текущего стола получает текущий мир (у него paint): иначе Esc «домой» перекрасил бы стол в чужой цвет
  function paint(h) {
    const id = Hyprland.focusedWorkspace?.id
    if (id > 0) stars = Object.assign({}, stars, { [id]: starOf(id).slice(0, 3).concat([h, landSeed]) })
  }
  function settle(h) {
    hue = h
    const f = random ? null : themeFor(h)
    curTheme = f ? f.t.id : ""
  }
  // мир сменился: собрать и применить тему этого мира (палитра, акцент) с землёй сида s
  function reroll(h, s, ws) {
    settle(h ?? snap(Math.random()))
    landSeed = s ?? Math.round(Math.random() * 997)
    seed = landSeed
    save()
    const f = themeFor(hue)
    if (f) Quickshell.execDetached(["omarchy-space-world", f.t.id, String(f.i), String(Math.round(landSeed)), String(ws ?? Hyprland.focusedWorkspace?.id ?? 1)])
  }

  function palette(h) {
    const f = random ? null : themeFor(h)
    if (f) {
      const c = f.t.c, colors = { color0: c[0], color7: c[1], color8: c[2], color15: c[1] }
      for (let i = 0; i < 6; i++) { colors["color" + (i + 1)] = c[3 + i]; colors["color" + (i + 9)] = c[3 + i] }
      colors.color9 = c[f.i]
      colors.color13 = c[3 + (f.i - 3 + 4) % 6]
      return { name: "Space", custom: true, colors: colors, special: { background: c[0], foreground: c[1], cursor: c[1] } }
    }
    const c = (dh, s, l) => String(Qt.hsla(((h + dh) % 1 + 1) % 1, s, l, 1))
    const tones = [0, 0.07, 0.14, 0.5, 0.57, -0.08]
    const colors = { color0: c(0, 0.35, 0.06), color7: c(0, 0.14, 0.78), color8: c(0, 0.18, 0.32), color15: c(0, 0.1, 0.94) }
    tones.forEach((t, i) => {
      colors["color" + (i + 1)] = c(t, 0.5, 0.52)
      colors["color" + (i + 9)] = c(t, 0.7, 0.68)
    })
    return { name: "Space", custom: true, colors: colors, special: { background: colors.color0, foreground: colors.color15, cursor: colors.color15 } }
  }
}

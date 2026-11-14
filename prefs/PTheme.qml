pragma Singleton
import QtQuick
import qs.Commons as Commons
import "../dotmatrix" as DM

// Вид окна Prefs по активному райсу (id стиля из ~/.config/omarchy/style.json — его читает dotmatrix/Finish.qml).
// Цвета — семь серых от фона к тексту темы, как у GTheme; шрифты, скругление, капс и движение — свои у каждого райса:
// glyph / dotmatrix — точечные цифры Doto и моно-капс; liquid / glass / neumorph — мягкие круглые формы; fluent —
// умеренные углы; flat / brutal — прямые; retro — пиксельный шрифт и почти прямые углы; paper — рукописный шрифт.
QtObject {
  id: t

  readonly property string rice: DM.Finish.styleId !== "" ? DM.Finish.styleId : "glyph"
  readonly property bool dotted: rice === "glyph" || rice === "dotmatrix"
  function pick(map) { return map[t.rice] !== undefined ? map[t.rice] : map["default"] }

  // ── цвета ──
  readonly property color bg: Commons.Color.background
  readonly property color fg: Commons.Color.foreground
  readonly property bool light: luma(bg) > 0.5
  function luma(c) { return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b }
  function mix(a, b, k) { return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, 1) }
  readonly property color s1: mix(bg, fg, 0.06)
  readonly property color s2: mix(bg, fg, 0.11)
  readonly property color s3: mix(bg, fg, 0.2)
  readonly property color mute: mix(bg, fg, 0.36)
  readonly property color grey: mix(bg, fg, 0.58)
  readonly property color ink: light ? s1 : bg
  // красный «живой» акцент — у точечных райсов (как у glyph-rice), у остальных — акцент темы
  readonly property color accent: dotted ? Commons.Color.urgent : Commons.Color.accent
  function fade(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  // ── шрифты ──
  // крупные слова и цифры: у точечных — Doto, у остальных — шрифт заголовков профиля (fonts.json title: у пресетов
  // Vitreus это шрифт темы — Audiowide, Orbitron, …), иначе текстовый
  readonly property string titleFont: String(DM.Finish.fonts.title || "")
  readonly property string dot: dotted ? "Doto" : (titleFont !== "" && Qt.fontFamilies().indexOf(titleFont) >= 0 ? titleFont : DM.Finish.textFont)
  readonly property bool doto: dot === "Doto"
  readonly property string mono: dotted ? "Space Mono" : DM.Finish.labelFont
  readonly property string ui: dotted ? "Space Grotesk" : DM.Finish.textFont
  readonly property bool upper: dotted || DM.Finish.upper
  readonly property int labelWeight: rice === "brutal" ? Font.Black : Font.Normal

  // ── форма ── r(x): во что превращается скругление x у этого райса
  function r(x) {
    var k = pick({ glyph: 1, dotmatrix: 1, liquid: 1, glass: 1, neumorph: 1, fluent: 0.35, neon: 0.3, paper: 0.15, retro: 0.08,
                   flat: 0, brutal: 0, "default": 0.6 })
    return Math.min(x, Math.max(0, x * k))
  }
  readonly property int border: pick({ brutal: 2, retro: 2, flat: 1, neon: 1, "default": 0 })

  // ── движение ──
  readonly property var glide: [0.25, 1, 0.5, 1, 1, 1]
  readonly property int t: Math.round(350 * pick({ retro: 0.6, brutal: 0.6, flat: 0.8, liquid: 1.2, glass: 1.1, "default": 1 }))
  function url(p) { return p ? "file://" + String(p).split("/").map(encodeURIComponent).join("/") : "" }
}

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import "." as N

// Отделка DOT-MATRIX-компонентов (Tile, CircleButton, SegSlider, Label, Txt, …) по стилю Customizer.
// look — id стиля из ~/.config/omarchy/style.json; dotmatrix — как раньше: круги, LED-сегменты, моно-капс.
// Если в ~/.config/omarchy/widgets.json widgetStyle = "dotmatrix" или стиля нет — всегда dotmatrix.
// Цвета — по-прежнему палитра DOT-MATRIX (в режиме theme она из темы), меняется только форма и шрифты.
QtObject {
  id: root

  property var style: ({})
  property var widgets: ({})
  property var fonts: ({})

  readonly property string styleId: String(style.id || "")
  readonly property string look: String(widgets.widgetStyle || "") === "dotmatrix" || styleId === "" ? "dotmatrix" : styleId
  readonly property bool dotmatrix: look === "dotmatrix"
  function pick(map) { return map[root.look] !== undefined ? map[root.look] : map["flat"] }

  readonly property var families: Qt.fontFamilies()
  function face(name, fallback) { return families.indexOf(name) >= 0 ? name : fallback }
  readonly property string handFont: root.face(String(fonts.title || "Caveat"), root.face("Caveat", Commons.Style.font.family))

  // ── форма ──
  // Радиус круглой кнопки / диска размера size.
  function round(size) {
    return root.pick({ dotmatrix: size / 2, glass: size / 2, neumorph: size / 2, fluent: Math.round(size * 0.28),
      paper: 4, neon: Math.round(size * 0.22), flat: 0, brutal: 0, retro: 0 })
  }
  readonly property int radius: root.pick({ dotmatrix: 14, glass: 14, fluent: 8, paper: 3, neumorph: 16, neon: 8, flat: 0 })
  readonly property int borderWidth: root.pick({ brutal: 2, neumorph: 0, flat: 1 })
  readonly property bool segmented: root.dotmatrix || root.look === "retro"
  readonly property int segGap: root.look === "retro" ? 2 : 3
  readonly property int segRadius: root.look === "retro" ? 0 : 3
  // Активный переключатель: DOT-MATRIX — «горящий» диск цвета текста, остальные — акцент.
  readonly property color on: root.dotmatrix ? N.Palette.lit : Commons.Color.accent
  readonly property color onInk: root.dotmatrix ? N.Palette.bg : (0.299 * root.on.r + 0.587 * root.on.g + 0.114 * root.on.b > 0.55 ? "#111111" : "#ffffff")

  // ── шрифты ──
  readonly property string labelFont: root.pick({
    dotmatrix: N.Palette.fontMono, paper: root.handFont, retro: root.face("Pixelify Sans", N.Palette.fontMono),
    neon: Commons.Style.font.family, brutal: Commons.Style.font.family, flat: Commons.Style.font.family
  })
  readonly property string textFont: root.pick({
    dotmatrix: N.Palette.fontSans, paper: root.face("Pangolin", root.handFont), retro: root.face("Pixelify Sans", N.Palette.fontSans),
    neon: Commons.Style.font.family, flat: String(fonts.profile || "stock") !== "stock" && fonts.sans ? root.face(String(fonts.sans), Commons.Style.font.family) : Commons.Style.font.family
  })
  readonly property bool upper: root.pick({ dotmatrix: true, brutal: true, neon: true, flat: false })
  readonly property int labelSize: root.pick({ paper: 15, retro: 11, flat: 10 })
  readonly property real tracking: root.upper ? 1.6 : 0.3
  readonly property int labelWeight: root.look === "brutal" ? Font.Black : Font.Normal

  property FileView styleFile: FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/style.json"
    watchChanges: true; printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.style = JSON.parse(text() || "{}") || {} } catch (e) { root.style = {} } }
    onLoadFailed: root.style = {}
  }
  property FileView widgetsFile: FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/widgets.json"
    watchChanges: true; printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.widgets = JSON.parse(text() || "{}") || {} } catch (e) { root.widgets = {} } }
    onLoadFailed: root.widgets = {}
  }
  property FileView fontsFile: FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/fonts.json"
    watchChanges: true; printErrors: false
    onFileChanged: reload()
    onLoaded: { try { root.fonts = JSON.parse(text() || "{}") || {} } catch (e) { root.fonts = {} } }
    onLoadFailed: root.fonts = {}
  }
}

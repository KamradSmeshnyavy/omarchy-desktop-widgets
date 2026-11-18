.pragma library
.import "SchemaShared.js" as Base

// Раскладка страниц панели Sheet по колонкам — как его Space/common/Schema.js (github.com/elifouts/Dotfiles, GPL-3.0),
// без его страницы «land» (земля Space у нас — в теме), плюс наши страницы.
var shown = Base.shown
var LAYOUT = {
    screen: [["Tube", "Glass"], ["Wallpaper filter"]],
    windows: [["Spacing", "Borders", "Opacity"], ["Tiling"], ["Behavior"]],
    effects: [["Blur"], ["Shadow", "Glow", "Focus"]],
    animations: [["Motion", "Details"], ["Curve"]],
    input: [["Mouse", "Keyboard"], ["Cursor behavior"], ["Touchpad", "Gestures"]],
    system: [["Display"], ["Behavior"]],
    home: [["Home screen"], ["Desktop widgets"]],
    deck: [["Deck"]],
    bar: [["Tray"], ["Window title"]],
    look: [["Wallpaper look"]],
    idle: [["Idle"]],
    shell: [["Parts of the rice"], ["Pickers and screens"]]
}
var PAGES = Object.keys(LAYOUT).map(function (id) {
    var p = Base.PAGES.find(function (x) { return x.id === id })
    return { id: id, columns: LAYOUT[id].map(function (col) {
        return col.map(function (label) { return p.sections.find(function (s) { return s.label === label }) })
    }) }
})
function keys() { return Base.keys() }

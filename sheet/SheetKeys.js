.pragma library
// Клавиши панели настроек для обликов Space / Vitreus (Sheet.qml), Retro CRT и Modern — те же, что в SkinWindow:
// Tab / Shift+Tab и [ / ] — вкладки, 1–9 — по номеру, стрелки / hjkl — по строкам (KeyNav), Enter / Space — нажать,
// / — поиск шрифтов, ? — подсказка, Esc — закрыть список → подсказку → панель. Буквы — по скан-коду (любая раскладка).
// ctx: { list (PickList), nav (KeyNav), tabs, tab, go(t), step(d), close(), help(), search(), digits (false — не трогать) }

var LATIN = { 43: "h", 44: "j", 45: "k", 46: "l", 34: "[", 35: "]", 61: "/", 10: "1", 11: "2", 12: "3", 13: "4", 14: "5", 15: "6", 16: "7", 17: "8", 18: "9" }

function handle(e, ctx) {
    var ch = LATIN[e.nativeScanCode] || ""
    var shift = (e.modifiers & Qt.ShiftModifier) !== 0
    if (ctx.list && ctx.list.opened) {
        ctx.list.keys(ch === "j" ? { key: Qt.Key_J, text: "" } : ch === "k" ? { key: Qt.Key_K, text: "" } : e)
        return true
    }
    if (ch === "/" && shift) ch = "?"
    var k = e.key
    if (k === Qt.Key_Escape) { if (ctx.helpOn && ctx.helpOn()) { ctx.help(); return true } ctx.close(); return true }
    if (k === Qt.Key_Tab && !shift) { ctx.step(1); return true }
    if (k === Qt.Key_Backtab || (k === Qt.Key_Tab && shift)) { ctx.step(-1); return true }
    if (ch === "[") { ctx.step(-1); return true }
    if (ch === "]") { ctx.step(1); return true }
    if (ch === "?" || e.text === "?") { if (ctx.help) ctx.help(); return true }
    if (ch === "/") { if (ctx.tabs.indexOf("fonts") !== -1) { ctx.go("fonts"); if (ctx.search) ctx.search() } return true }
    if (ctx.digits !== false && /^[1-9]$/.test(ch) && !(e.modifiers & Qt.ControlModifier)) {
        var t = ctx.tabs[Number(ch) - 1]
        if (t) ctx.go(t)
        return true
    }
    var vim = { h: Qt.Key_Left, j: Qt.Key_Down, k: Qt.Key_Up, l: Qt.Key_Right }
    if (vim[ch]) return ctx.nav.handle({ key: vim[ch], modifiers: e.modifiers, text: "" })
    return ctx.nav.handle(e)
}

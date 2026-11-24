import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import ".." as W

// Окно панели настроек для обликов райсов (SheetRumda, SheetYami, …): слой на весь экран, видимое — только region
// (карточка облика). Здесь общее: открытие / закрытие (k 0→1, облик рисует по k свою анимацию), фокус, клавиатура,
// KeyNav, выпадающий список (PickList) и подсказка «?».
// Клавиши: Tab / Shift+Tab и [ / ] — вкладки, 1–9 — вкладка по номеру, стрелки / hjkl — по строкам, ←/→ на ползунке —
// шаг, Enter / Space — нажать (на выборе — открыть список), / — поиск шрифтов, ? — подсказка, Esc — закрыть список →
// назад (back) → закрыть панель. Буквы работают и в русской раскладке (по скан-коду).
PanelWindow {
  id: w
  signal done()
  visible: true
  screen: Ui.target
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  mask: Region { item: w.region }
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "omarchy-prefs"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  property Item region: null
  readonly property var tabs: SheetCore.tabs
  property string tab: tabs.indexOf(Ui.sheet) !== -1 ? Ui.sheet : "core"
  property int dir: 1
  property real k: 0
  property bool leaving: false
  property bool help: false
  property int openMs: 420
  property int closeMs: 240
  property var openEasing: Easing.OutCubic
  // Esc внутри облика (Surface — из раздела на главную); true — съедено
  property var back: null
  default property alias chrome: holder.data
  readonly property alias nav: nav
  readonly property alias keyItem: keyItem
  readonly property alias pickList: plist
  signal search()

  function go(t) {
    if (!t || t === tab) return
    dir = tabs.indexOf(t) >= tabs.indexOf(tab) ? 1 : -1
    tab = t
    Ui.sheet = t
  }
  function step(d) { go(tabs[(tabs.indexOf(tab) + d + tabs.length) % tabs.length]) }
  function close() { if (leaving) return; leaving = true; plist.close(); openAnim.stop(); closeAnim.from = k; closeAnim.start() }
  function open() { leaving = false; closeAnim.stop(); openAnim.from = k; openAnim.start() }

  NumberAnimation { id: openAnim; target: w; property: "k"; to: 1; duration: w.openMs; easing.type: w.openEasing }
  NumberAnimation { id: closeAnim; target: w; property: "k"; to: 0; duration: w.closeMs; easing.type: Easing.InCubic; onFinished: w.done() }
  HyprlandFocusGrab { active: !w.leaving; windows: [w]; onCleared: w.close() }

  Component.onCompleted: {
    StoreShared.refresh()
    Sk.list = plist
    Sk.keys = keyItem
    Sk.nav = nav
    openAnim.from = 0
    openAnim.start()
    keyItem.forceActiveFocus()
  }

  // скан-код (xkb = evdev + 8) → латинская буква: hjkl, [ ] / ? и цифры в любой раскладке
  readonly property var latin: ({ 43: "h", 44: "j", 45: "k", 46: "l", 34: "[", 35: "]", 61: "/", 10: "1", 11: "2", 12: "3", 13: "4", 14: "5", 15: "6", 16: "7", 17: "8", 18: "9" })
  function handle(e) {
    if (plist.opened) {
      const lk = latin[e.nativeScanCode]
      plist.keys(lk === "j" ? { key: Qt.Key_J, text: "" } : lk === "k" ? { key: Qt.Key_K, text: "" } : e)
      return true
    }
    const key = e.key, shift = (e.modifiers & Qt.ShiftModifier) !== 0
    let ch = latin[e.nativeScanCode] || ""
    if (ch === "/" && shift) ch = "?"
    if (key === Qt.Key_Escape) {
      if (w.help) { w.help = false; return true }
      if (w.back && w.back()) return true
      w.close(); return true
    }
    if (key === Qt.Key_Backspace && w.back && w.back()) return true
    if (key === Qt.Key_Tab && !shift) { w.step(1); return true }
    if (key === Qt.Key_Backtab || (key === Qt.Key_Tab && shift)) { w.step(-1); return true }
    if (ch === "[") { w.step(-1); return true }
    if (ch === "]") { w.step(1); return true }
    if (ch === "?" || e.text === "?") { w.help = !w.help; return true }
    if (ch === "/") { w.go("fonts"); searchLater.restart(); return true }
    if (/^[1-9]$/.test(ch) && !(e.modifiers & Qt.ControlModifier)) { const t = w.tabs[Number(ch) - 1]; if (t) w.go(t); return true }
    // hjkl — как стрелки (в любой раскладке)
    const vim = { h: Qt.Key_Left, j: Qt.Key_Down, k: Qt.Key_Up, l: Qt.Key_Right }
    if (vim[ch]) return nav.handle({ key: vim[ch], modifiers: e.modifiers, text: "" })
    return nav.handle(e)
  }
  Timer { id: searchLater; interval: 60; onTriggered: w.search() }

  Item {
    id: keyItem
    focus: true
    Keys.onPressed: e => { if (!keyItem.activeFocus) return; if (w.handle(e)) e.accepted = true }
  }

  Item {
    id: holder
    anchors.fill: parent
  }
  // нажатие в панели возвращает фокус клавиатуре (поле ввода получит его своим кликом следом)
  MouseArea {
    anchors.fill: parent
    z: 900
    onPressed: m => { keyItem.forceActiveFocus(); m.accepted = false }
  }
  W.KeyNav {
    id: nav
    anchors.fill: parent
    z: 999
    scope: w.region
    vim: false
    active: !plist.opened && !w.leaving
    ring: Sk.c("ring", Sk.c("accent"))
    ringWidth: Sk.n("ringWidth", 2)
  }
  PickList { id: plist }

  // подсказка «?»
  Rectangle {
    visible: w.help && !!w.region
    z: 4000
    readonly property var rows: [["Tab  [ ]  1–9", "tabs"], ["↑ ↓ ← →  h j k l", "move"], ["← →  on a slider", "step"], ["Enter  Space", "press · open a list"], ["↑ ↓  Enter  in a list", "choose · apply"], ["/", "search fonts"], ["right click", "default value"], ["Esc", "close list · back · close"]]
    width: 360; height: rows.length * 22 + 20
    x: w.region ? Math.round(w.region.mapToItem(null, 0, 0).x + (w.region.width - width) / 2) : 0
    y: w.region ? Math.round(w.region.mapToItem(null, 0, 0).y + (w.region.height - height) / 2) : 0
    radius: Sk.n("radius", 6)
    color: Sk.c("card", Sk.c("bg"))
    border.width: Math.max(1, Sk.n("border", 1)); border.color: Sk.c("accent")
    Column {
      x: 14; y: 10
      Repeater {
        model: parent.parent.rows
        Row {
          required property var modelData
          height: 22
          Text { width: 170; text: modelData[0]; color: Sk.c("accent"); font.family: Sk.s("font", "monospace"); font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
          Text { text: modelData[1]; color: Sk.c("ink"); font.family: Sk.s("font", "monospace"); font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
        }
      }
    }
  }
}

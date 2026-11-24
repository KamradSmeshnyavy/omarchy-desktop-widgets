pragma Singleton

import QtQuick
import Quickshell

// Облик открытой панели настроек для общих ручек (SkToggle, SkSlider, SkPick, SkTitle, PickList, SkPage).
// Открытой бывает одна панель, поэтому токены — здесь: облик райса (SheetRumda, SheetYami, …) кладёт свои в `t`
// привязкой (Binding), ручки читают Sk.t.<токен>. Встроенные компоненты не видят внешних id — синглтон видят все.
//   цвета: bg (фон панели), card (подложка блоков), ink, dim, accent, onAccent, line, sel (фон выбранной строки)
//   шрифт: font, head (заголовки), size, caps, spacing (разрядка)
//   форма: radius, border, shadow (сдвиг жёсткой тени), shadowColor
//   вид ручек: toggle pill|check|dot|led|capsule|square, slider bar|blocks|dots|line|cells,
//              title rule|comment|sticker|plain|bar|stripe, popup list|completion
Singleton {
  id: sk
  property var t: ({})
  property var list: null          // PickList открытой панели
  property Item keys: null         // держатель фокуса клавиатуры (поля ввода отдают ему Esc / Tab)
  property var nav: null           // KeyNav панели: текущая строка (Unit-3 — «Описание»)
  function c(name, dflt) { var v = t[name]; return v === undefined || v === null ? (dflt === undefined ? "#888888" : dflt) : v }
  function n(name, dflt) { var v = t[name]; return v === undefined || v === null ? dflt : v }
  function s(name, dflt) { var v = t[name]; return v === undefined || v === null ? dflt : String(v) }
  function alpha(c, a) { c = Qt.color(c); return Qt.rgba(c.r, c.g, c.b, a) }
  function mix(a, b, k) { a = Qt.color(a); b = Qt.color(b); return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, 1) }
  function lum(c) { c = Qt.color(c); return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b }
  function ink(on) { return lum(on) > 0.55 ? "#1b1712" : "#f6f2ea" }
  function cap(x) { return n("caps", false) ? String(x).toUpperCase() : String(x) }
  function family(name, fallback) { return Qt.fontFamilies().indexOf(name) !== -1 ? name : fallback }
}

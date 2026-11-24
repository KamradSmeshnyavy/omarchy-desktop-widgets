pragma Singleton

import QtQuick
import Quickshell
import "Schema.js" as Schema

// Данные панели настроек, общие для обликов райсов: вкладки, райс / вариант / бар (вкладка «Райсы» Customizer),
// темы райса и акцент (omarchy-rice-accent). Хранилище — StoreShared.
Singleton {
  id: core
  // вкладка — только если в ней есть что показать
  readonly property var tabs: ["core", "colors", "fonts"].concat(Schema.PAGES.filter(p => p.columns.some(col => col.some(sec => sec.controls.some(c => Schema.shown(c, StoreShared.values, StoreShared.caps))))).map(p => p.id), "profiles")
  function page(id) { return Schema.PAGES.find(p => p.id === id) }
  function shown(c) { return Schema.shown(c, StoreShared.values, StoreShared.caps) }
  function title(id) { return ({ core: "Core", colors: "Colors", fonts: "Fonts", profiles: "Profiles", screen: "Screen", windows: "Windows", effects: "Effects", animations: "Animations", input: "Input", system: "System", home: "Home", deck: "Deck", bar: "Bar", look: "Look", idle: "Idle", shell: "Shell" })[id] || id }
  // значок вкладки (Nerd Font)
  function icon(id) { return ({ core: "\u{F0493}", colors: "\u{F03D8}", fonts: "\u{F0284}", profiles: "\u{F0004}", screen: "\u{F0379}", windows: "\u{F05B3}", effects: "\u{F0BB8}", animations: "\u{F1061}", input: "\u{F030C}", system: "\u{F048B}", home: "\u{F02DC}", deck: "\u{F0570}", bar: "\u{F0352}", look: "\u{F02E9}", idle: "\u{F04B2}", shell: "\u{F018D}" })[id] || "\u{F0493}" }

  // райс и его варианты
  readonly property var riceHeads: (StoreShared.lists.rices || []).filter(r => r.header)
  function riceVariants(name) {
    const l = StoreShared.lists.rices || [], out = []
    let on = false
    for (const r of l) {
      if (r.header) { on = r.label === name; continue }
      if (on) out.push(r)
    }
    return out
  }
  function slug(x) { return String(x).toLowerCase().replace(/[^a-z0-9]/g, "") }
  function presetOf(r) { return String(r.value).split("/").pop().replace(/\.json$/, "") }
  readonly property string riceNow: (riceHeads.find(h => riceVariants(h.label).some(r => presetOf(r) === StoreShared.active.preset))
      || riceHeads.find(h => slug(h.label) === slug(StoreShared.active.rice)) || {}).label || ""
  readonly property var riceOptions: riceHeads.map(h => ({ v: h.label, l: h.label }))
  function chooseRice(name) {
    const vs = riceVariants(name)
    if (name !== riceNow && vs.length) StoreShared.act("rice", [vs[0].value])
  }
  readonly property var variantOptions: riceVariants(riceNow).map(r => ({ v: r.value, l: r.label.split(" · ").pop() }))
  readonly property var variantNow: (riceVariants(riceNow).find(r => presetOf(r) === StoreShared.active.preset) || {}).value
  readonly property var barOptions: (StoreShared.lists.bars || []).filter(b => b.value !== "save").map(b => ({ v: b.value, l: b.label.replace(/^★ /, "") }))
  readonly property var barNow: ((StoreShared.lists.bars || []).find(b => b.cur) || {}).value

  // темы райса (из его профилей) и его dynamic; без райса — все темы
  readonly property string theme: StoreShared.lists.theme || ""
  readonly property var riceThemes: {
    const l = StoreShared.lists, all = l.themes || []
    if (!l.rice) return all
    const own = all.filter(t => (l.riceThemes || []).indexOf(t.id) !== -1 || t.id === "dynamic-" + l.rice)
    return own.length ? own : all
  }
  // тема применена: сама или её копия с акцентом (<тема>-accent)
  function themeUsed(id) { return theme === id || theme === id + "-accent" }

  // акцент: ряды «тема» и «обои», текущий, сброс
  readonly property var accent: StoreShared.lists.accent || ({})
  readonly property var accentTheme: accent.theme || []
  readonly property var accentWall: accent.wall || []
  readonly property string accentNow: String(accent.accent || "").toLowerCase()
  readonly property bool accentCustom: !!accent.custom
  function setAccent(hex) { StoreShared.act("riceAccent", [hex]) }
  function resetAccent() { StoreShared.act("riceAccent", ["reset"]) }

  // профили райса
  readonly property bool ownProfiles: !!StoreShared.lists.rice
  readonly property var profiles: ownProfiles ? (StoreShared.lists.profiles || []) : (StoreShared.lists.presets || []).filter(e => e.value !== "save" && !e.header)
  function profileName(p) { return ownProfiles ? p.name : String(p.label).replace(/^[★↩] /, "") }
  function profileUsed(p) { return ownProfiles ? p.id === StoreShared.active.preset : !!p.cur }
  function applyProfile(p) { if (ownProfiles) StoreShared.act("profile", [p.path]); else StoreShared.act("preset", [p.value]) }

  // шрифты
  readonly property var fonts: (StoreShared.lists.fonts || []).filter(f => !f.header)
  readonly property string fontNow: (fonts.find(f => f.cur) || {}).label || ""

  // текущее значение выбора (как Pick в Sheet.qml: "" — вариант по умолчанию)
  function current(def) {
    const raw = StoreShared.values[def.key]
    if (raw === "" || raw === undefined || raw === null) return (def.options.find(o => o.dflt) || {}).v ?? def.dflt
    return raw
  }
}

import QtQuick

// Панель настроек Sheet (Super+Alt+I) — его Space/settings/Settings.qml (github.com/elifouts/Dotfiles, GPL-3.0) почти
// дословно: полоса снизу раскрывается в лист, вкладки сверху с подчёркиванием, страницы по схеме (Schema.js), его
// ручки (слова-варианты, тумблеры, шкалы из клеток, редактор кривой). Хранилище — StoreShared → sheet.py (Hyprland,
// Customizer, виджеты). Свои вкладки: CORE (райс, вариант, бар), COLORS (миры Space / темы Omarchy), FONTS (профили
// шрифтов), PROFILES (пресеты Customizer), плюс страницы прежней панели Prefs (home, deck, look, idle, shell).
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "MotionShared.js" as Motion
import "Schema.js" as Schema

PanelWindow {
    id: sheet

    signal done()
    visible: true
    screen: Ui.target
    anchors.bottom: true
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: Math.min(1240, (screen?.width ?? 1240) - 32)
    implicitHeight: 560
    color: "transparent"
    mask: Region { item: frame }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-prefs"
    WlrLayershell.keyboardFocus: Ui.touring ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

    property string tab: Ui.sheet
    // вкладка — только если в ней есть что показать (страница bar — только при раскладке glyph-rice)
    readonly property var tabs: ["core", "colors", "fonts"].concat(Schema.PAGES.filter(p => p.columns.some(col => col.some(sec => sec.controls.some(c => Schema.shown(c, StoreShared.values, StoreShared.caps))))).map(p => p.id), "profiles")
    readonly property var page: Schema.PAGES.find(p => p.id === tab)
    property int dir: 1
    property int was: tabs.indexOf(tab)
    onTabChanged: {
        const i = tabs.indexOf(tab)
        dir = i >= was ? 1 : -1
        was = i
        swap.restart()
    }
    Component.onCompleted: { StoreShared.refresh(); morph.open() }
    function close() { morph.close() }
    function open() { morph.open() }
    function toggle() { morph.leaving ? morph.open() : morph.close() }
    MorphShared { id: morph; openMs: 560; closeMs: 340; onClosed: sheet.done() }
    property real w: Math.min(implicitWidth, Math.max(tabRow.implicitWidth + 96, content.implicitWidth + 48))
    property real h: Math.min(implicitHeight, content.implicitHeight + 46)
    Behavior on w { SettleShared { duration: Theme.fast } }
    Behavior on h { SettleShared { duration: Theme.fast } }
    function step(d) {
        tab = tabs[(tabs.indexOf(tab) + d + tabs.length) % tabs.length]
    }
    HyprlandFocusGrab { active: !Ui.touring && !morph.leaving; windows: [sheet]; onCleared: sheet.close() }

    component Caption: DecodeText { width: 150; height: 20; caps: false; elide: Text.ElideRight; color: Theme.dim }
    component Pick: Flow {
        id: pick
        property string label
        property var options: []
        property string key
        property var fallback
        readonly property var raw: StoreShared.values[key]
        property var current: raw === "" ? options.find(o => o.dflt)?.v : raw ?? fallback
        readonly property bool many: options.length > 6
        readonly property var shown: many ? [options.find(o => (o.v ?? o) === current) ?? options[0]] : options
        readonly property bool fits: shown.reduce((n, o) => n + String(o.l ?? o).length * 8.2 + 12, 0) <= width - 158
        signal chose(var v)
        onChose: v => { if (key) StoreShared.set(key, v) }
        function next(d) {
            const i = options.findIndex(o => (o.v ?? o) === current), o = options[(i + d + options.length) % options.length]
            chose(o.v ?? o)
        }
        width: 320
        Caption { width: 158; text: pick.label }
        Flow {
            width: pick.fits ? pick.width - 158 : pick.width
            spacing: 12
            Repeater {
                model: pick.shown
                DecodeText {
                    required property var modelData
                    readonly property var v: modelData.v ?? modelData
                    text: (modelData.l ?? modelData) + (pick.many ? " \u203a" : "")
                    height: 20
                    color: v === pick.current ? Theme.accent : area.containsMouse ? Theme.fg : Theme.dim
                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: pick.many ? pick.next(1) : pick.chose(parent.v)
                        onWheel: w => { if (pick.many) pick.next(w.angleDelta.y < 0 ? 1 : -1) }
                    }
                }
            }
        }
    }
    component Toggle: Item {
        id: tg
        property string label
        property string key
        property bool fallback: true
        property var raises
        readonly property bool on: !!(StoreShared.values[key] ?? fallback)
        width: 320
        implicitHeight: 20
        Caption { width: tg.width - 40; text: tg.label }
        Controls.Toggle {
            anchors.right: parent.right
            height: 20
            on: tg.on
            onFlip: {
                const r = tg.raises, next = { [tg.key]: !tg.on }
                if (!tg.on && r && StoreShared.values[r.key] < r.min) next[r.key] = r.min
                StoreShared.setMany(next)
            }
        }
    }
    component Knob: Row {
        id: knob
        property string key
        property string label
        property string unit
        property real from: 0
        property real to: 1
        property real step: 1
        property real fallback: from
        readonly property real v: StoreShared.values[key] ?? fallback
        readonly property int digits: (String(step).split(".")[1] ?? "").length
        width: 320
        spacing: 8
        Caption { text: knob.label }
        Controls.Slide {
            width: knob.width - 158
            height: 20
            scrollable: false
            readout: knob.v.toFixed(knob.digits) + knob.unit
            value: (knob.v - knob.from) / (knob.to - knob.from)
            onMoved: x => StoreShared.set(knob.key, Number((Math.round((knob.from + x * (knob.to - knob.from)) / knob.step) * knob.step).toFixed(knob.digits)))
        }
    }

    Rectangle {
        id: frame
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -(1 - morph.rise) * 18
        readonly property real fw: 44 + (sheet.w - 44) * Math.min(1, morph.mw)
        x: Math.round((sheet.width - fw) / 2)
        width: Math.round((sheet.width + fw) / 2) - x
        height: Math.round(10 + (sheet.h - 10) * Math.min(1, morph.mh))
        opacity: Math.min(1, morph.t * 6)
        clip: true
        color: Theme.back(0.8)
        border.width: 1
        border.color: Theme.alpha(Theme.accent, 0.3)
        Rectangle { width: parent.width; height: 2; color: Theme.accent }
        MouseArea {
            anchors.fill: parent
            z: 1
            onPressed: m => { sheetKeys.forceActiveFocus(); m.accepted = false }
        }

        Item {
            x: Math.round((frame.fw - sheet.w) / 2)
            width: Math.round(sheet.w)
            height: Math.round(sheet.h)
            opacity: morph.stage(0.5)

            Row {
                id: tabRow
                x: 24
                y: 10
                spacing: 18
                Repeater {
                    id: tabItems
                    model: sheet.tabs
                    DecodeText {
                        required property string modelData
                        text: modelData
                        color: sheet.tab === modelData ? Theme.accent : Theme.dim
                        MouseArea { anchors.fill: parent; onClicked: sheet.tab = parent.modelData }
                    }
                }
            }
            Rectangle {
                readonly property Item on: tabItems.count ? tabItems.itemAt(sheet.tabs.indexOf(sheet.tab)) : null
                x: tabRow.x + (on?.x ?? 0)
                y: tabRow.y + tabRow.height + 3
                width: on?.width ?? 0
                height: 1
                color: Theme.accent
                Behavior on x { SettleShared { duration: Theme.fast } }
                Behavior on width { SettleShared { duration: Theme.fast } }
            }
            DecodeText { anchors.right: parent.right; anchors.rightMargin: 24; y: 10; text: "esc"; color: Theme.alpha(Theme.fg, 0.25) }

            Loader {
                id: content
                x: 24
                y: 34
                transform: Translate { id: shift }
                onLoaded: sheetKeys.forceActiveFocus()
                sourceComponent: ({ core: core, colors: colors, fonts: fonts, profiles: profiles })[sheet.tab] ?? pageView
            }
            ParallelAnimation {
                id: swap
                SettleShared { target: content; property: "opacity"; from: 0; to: 1; duration: Theme.fast }
                SettleShared { target: shift; property: "x"; from: 24 * sheet.dir; to: 0; duration: Theme.fast }
            }
        }
    }

    // райс и его вариант (вкладка «Райсы» Customizer), скин бара
    readonly property var riceHeads: StoreShared.lists.rices.filter(r => r.header)
    function riceVariants(name) {
        const l = StoreShared.lists.rices, out = []
        let on = false
        for (const r of l) {
            if (r.header) { on = r.label === name; continue }
            if (on) out.push(r)
        }
        return out
    }
    function slug(x) { return String(x).toLowerCase().replace(/[^a-z0-9]/g, "") }
    function presetOf(r) { return String(r.value).split("/").pop().replace(/\.json$/, "") }
    // райс — тот, среди вариантов которого активный пресет; иначе — по имени (id «crt» ≠ заголовок «Retro CRT»)
    readonly property string riceNow: (riceHeads.find(h => riceVariants(h.label).some(r => presetOf(r) === StoreShared.active.preset))
        || riceHeads.find(h => slug(h.label) === slug(StoreShared.active.rice)) || {}).label || ""
    property string riceSel: riceNow
    Component {
        id: core
        Row {
            spacing: 24
            Column {
                Pick {
                    label: "Rice"
                    options: sheet.riceHeads.map(h => h.label)
                    current: sheet.riceSel || sheet.riceNow
                    onChose: v => {
                        sheet.riceSel = v
                        const vs = sheet.riceVariants(v)
                        if (v !== sheet.riceNow && vs.length) StoreShared.act("rice", [vs[0].value])
                    }
                }
                Pick {
                    label: "Variant"
                    options: sheet.riceVariants(sheet.riceSel || sheet.riceNow).map(r => ({ v: r.value, l: r.label.split(" · ").pop() }))
                    current: (sheet.riceVariants(sheet.riceSel || sheet.riceNow).find(r => String(r.value).split("/").pop().replace(/\.json$/, "") === StoreShared.active.preset) || {}).value
                    onChose: v => StoreShared.act("rice", [v])
                }
            }
            Column {
                Pick {
                    label: "Bar"
                    options: StoreShared.lists.bars.filter(b => b.value !== "save").map(b => ({ v: b.value, l: b.label.replace(/^★ /, "") }))
                    current: (StoreShared.lists.bars.find(b => b.cur) || {}).value
                    onChose: v => StoreShared.act("bar", [v])
                }
            }
        }
    }

    Component {
        id: profiles
        Row {
            spacing: 24
            ListView {
                id: plist
                width: 320
                height: Math.min(168, Math.max(72, count * 24))
                clip: true
                // у райса — только его профили (rices.json → profiles и свои сохранённые с полем rice), без райса — все пресеты
                readonly property bool own: !!StoreShared.lists.rice
                model: own ? (StoreShared.lists.profiles || [])
                    : StoreShared.lists.presets.filter(e => e.value !== "save" && !e.header)
                delegate: Controls.Line {
                    required property var modelData
                    property bool armed: false
                    readonly property bool cur: plist.own ? modelData.id === StoreShared.active.preset : modelData.cur
                    width: 320
                    glyph: cur ? "◆" : "◇"
                    text: plist.own ? modelData.name : modelData.label.replace(/^[★↩] /, "")
                    value: plist.own ? (armed ? "rclick again — delete" : modelData.mine ? "mine" : "profile")
                        : modelData.label.startsWith("★") ? "mine" : modelData.label.startsWith("↩") ? "undo" : "preset"
                    lit: cur
                    onClicked: m => {
                        if (!plist.own) { if (m.button === Qt.LeftButton) StoreShared.act("preset", [modelData.value]); return }
                        if (m.button === Qt.LeftButton) return StoreShared.act("profile", [modelData.path])
                        if (!modelData.mine) return
                        if (armed) StoreShared.act("delete", [modelData.id])
                        armed = !armed
                    }
                }
            }
            Column {
                spacing: 8
                DecodeText { text: "save as"; color: Theme.alpha(Theme.fg, 0.35) }
                Field {
                    width: 320
                    placeholder: "name"
                    keysTo: [sheetKeys]
                    onAccepted: { if (text.trim()) StoreShared.act("save", [text.trim()]); text = ""; sheetKeys.forceActiveFocus() }
                }
            }
        }
    }

    Component {
        id: pageView
        Row {
            spacing: 24
            Repeater {
                model: sheet.page?.columns ?? []
                Column {
                    id: col
                    required property var modelData
                    required property int index
                    readonly property var all: modelData.reduce((a, s) => a.concat(s.controls), [])
                    width: all.some(c => c.type === "bezier") ? 560 : 320
                    visible: all.some(c => Schema.shown(c, StoreShared.values, StoreShared.caps))
                    spacing: 10
                    Repeater {
                        model: col.modelData
                        Column {
                            id: sec
                            required property var modelData
                            required property int index
                            visible: modelData.controls.some(c => Schema.shown(c, StoreShared.values, StoreShared.caps))
                            width: col.width
                            spacing: 2
                            Controls.Title { glyph: "\u25c6"; text: sec.modelData.label }
                            Repeater {
                                model: sec.modelData.controls
                                Loader {
                                    id: ctl
                                    required property var modelData
                                    readonly property var def: modelData
                                    width: sec.width
                                    height: item?.implicitHeight ?? 0
                                    visible: Schema.shown(def, StoreShared.values, StoreShared.caps)
                                    active: visible
                                    sourceComponent: ({ slider: slider, toggle: flip, choice: choice, bezier: bezier, animpreset: preset })[def.type]
                                    Component { id: slider; Knob { key: ctl.def.key; label: ctl.def.label; unit: ctl.def.unit; from: ctl.def.min; to: ctl.def.max; step: ctl.def.step; fallback: ctl.def.dflt ?? ctl.def.min } }
                                    Component { id: flip; Toggle { key: ctl.def.key; label: ctl.def.label; raises: ctl.def.raises; fallback: ctl.def.dflt ?? true } }
                                    Component { id: choice; Pick { key: ctl.def.key; label: ctl.def.label; options: ctl.def.options } }
                                    Component { id: bezier; SettingBezierShared {} }
                                    Component {
                                        id: preset
                                        Pick {
                                            label: "Preset"
                                            options: Motion.PRESET_OPTIONS
                                            current: StoreShared.values["animation.preset"] || "theme"
                                            onChose: v => Motion.pick(StoreShared, v, StoreShared.values["animation.curve"] || Motion.CURVE)
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.RightButton
                                        onClicked: StoreShared.reset(ctl.def.key ?? "animation")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // его миры (9 палитр × акцент) — у райса Space через omarchy-space-world; у остальных — установленные темы Omarchy
    readonly property var worlds: [
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
    readonly property var accentNames: ["", "", "", "red", "green", "yellow", "blue", "purple", "cyan"]
    property var world: null
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/world.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { sheet.world = JSON.parse(text()) } catch (e) { sheet.world = null } }
        onLoadFailed: sheet.world = null
    }
    readonly property var spaceVariants: ({ "space-dusk": ["dracula", 8], "space-mars": ["gruvbox", 3], "space-atlas": ["nord", 3], "space-frost": ["tokyonight", 8] })
    readonly property var applied: {
        const n = StoreShared.lists.theme
        if (n === "space-world" && world) return { t: world.theme, i: world.acc }
        const v = spaceVariants[n]
        return v ? { t: v[0], i: v[1] } : null
    }
    function newWorld() {
        const t = worlds[Math.floor(Math.random() * worlds.length)], i = 3 + Math.floor(Math.random() * 6)
        StoreShared.act("world", [t.id, String(i), String(1 + Math.floor(Math.random() * 996))])
    }
    Component {
        id: colors
        Column {
            spacing: 8
            readonly property bool space: Theme.rice === "space"
            Row {
                spacing: 12
                Button { visible: parent.parent.space; label: "new world"; onPressed: sheet.newWorld() }
                Rectangle { width: 12; height: 12; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                DecodeText {
                    height: 24
                    color: Theme.fg
                    text: sheet.applied ? sheet.worlds.find(w => w.id === sheet.applied.t).name + "  //  " + sheet.accentNames[sheet.applied.i] : StoreShared.lists.theme
                }
                DecodeText { height: 24; visible: parent.parent.space; text: "click a swatch to apply"; color: Theme.alpha(Theme.fg, 0.35) }
            }
            // Space: его девять миров, клик по цвету — этот акцент
            Grid {
                visible: parent.space
                columns: 9
                spacing: 6
                Repeater {
                    model: sheet.worlds
                    Item {
                        id: tile
                        required property var modelData
                        readonly property bool used: sheet.applied?.t === modelData.id
                        width: 84
                        height: 112
                        Rectangle {
                            anchors.fill: parent
                            color: Theme.alpha(Theme.accent, tile.used ? 0.1 : ma.containsMouse ? 0.06 : 0.02)
                            border.width: 1
                            border.color: tile.used ? Theme.accent : Theme.alpha(Theme.fg, 0.12)
                        }
                        DecodeText { x: 8; y: 6; font.pixelSize: 9; text: tile.modelData.name; color: tile.used ? Theme.fg : Theme.dim }
                        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true }
                        Column {
                            z: 2
                            x: 8
                            y: 24
                            spacing: 2
                            Repeater {
                                model: [0, 3, 4, 5, 6, 7, 8]
                                Rectangle {
                                    id: sw
                                    required property int modelData
                                    width: 68
                                    height: 10
                                    color: tile.modelData.c[modelData]
                                    DecodeText { visible: tile.used && sheet.applied.i === sw.modelData; anchors.centerIn: parent; font.pixelSize: 9; text: "accent"; color: tile.modelData.c[0] }
                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: sw.modelData > 2
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: StoreShared.act("world", [tile.modelData.id, String(sw.modelData), String(1 + Math.floor(Math.random() * 996))])
                                    }
                                }
                            }
                        }
                    }
                }
            }
            // остальные райсы: темы самого райса (из его профилей) и его dynamic-тема; без райса — все темы Omarchy
            GridView {
                readonly property var own: StoreShared.lists.rice ? StoreShared.lists.themes.filter(t =>
                    (StoreShared.lists.riceThemes || []).indexOf(t.id) !== -1 || t.id === "dynamic-" + StoreShared.lists.rice) : []
                visible: !parent.space
                width: 9 * 90
                height: Math.min(2, Math.ceil(Math.max(1, count) / 9)) * 118
                clip: true
                cellWidth: 90
                cellHeight: 118
                model: own.length ? own : StoreShared.lists.themes
                delegate: Item {
                    id: th
                    required property var modelData
                    readonly property bool used: StoreShared.lists.theme === modelData.id
                    width: 84
                    height: 112
                    Rectangle {
                        anchors.fill: parent
                        color: Theme.alpha(Theme.accent, th.used ? 0.1 : tm.containsMouse ? 0.06 : 0.02)
                        border.width: 1
                        border.color: th.used ? Theme.accent : Theme.alpha(Theme.fg, 0.12)
                    }
                    DecodeText { x: 8; y: 6; width: 70; elide: Text.ElideRight; caps: false; font.pixelSize: 9; text: th.modelData.id; color: th.used ? Theme.fg : Theme.dim }
                    Column {
                        x: 8; y: 24; spacing: 2
                        Repeater { model: th.modelData.c; Rectangle { required property string modelData; width: 68; height: 10; color: modelData } }
                    }
                    MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: StoreShared.act("theme", [th.modelData.id]) }
                }
            }
        }
    }

    // профили шрифтов Omarchy / Customizer (omarchy-font-profile): имя — его шрифтом, справа — что в нём
    Component {
        id: fonts
        Column {
            id: fontsCol
            spacing: 8
            readonly property var rows: StoreShared.lists.fonts.filter(f => !f.header)
            Row {
                spacing: 14
                DecodeText { width: 60; height: 24; text: "font"; color: Theme.dim }
                Field { id: find; width: 260; placeholder: "search"; keysTo: [sheetKeys]; onAccepted: sheetKeys.forceActiveFocus() }
                DecodeText { height: 24; color: Theme.accent; text: (fontsCol.rows.find(f => f.cur) || {}).label || "" }
            }
            GridView {
                width: 720
                height: 156
                clip: true
                cellWidth: width / 3
                cellHeight: 24
                model: fontsCol.rows.filter(f => (f.label + " " + f.note).toLowerCase().includes(find.text.toLowerCase()))
                delegate: Item {
                    required property var modelData
                    width: GridView.view.cellWidth
                    height: 24
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 10
                        elide: Text.ElideRight
                        text: parent.modelData.label
                        font.family: Theme.font
                        font.pixelSize: 13
                        color: parent.modelData.cur ? Theme.accent : fh.containsMouse ? Theme.fg : Theme.dim
                    }
                    MouseArea { id: fh; anchors.fill: parent; hoverEnabled: true; onClicked: StoreShared.act("font", [parent.modelData.value]) }
                }
            }
        }
    }

    Item {
        id: sheetKeys
        focus: true
        Keys.onEscapePressed: activeFocus ? sheet.close() : forceActiveFocus()
        Keys.onTabPressed: sheet.step(1)
        Keys.onBacktabPressed: sheet.step(-1)
    }
}

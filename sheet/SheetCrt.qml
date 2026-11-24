import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import ".."
import "MotionShared.js" as Motion
import "Schema.js" as Schema
import "SheetKeys.js" as SheetKeys

// Скин crt панели настроек — его Retro/settings/Settings.qml (github.com/elifouts/Dotfiles, GPL-3.0) почти дословно:
// двойная рамка SETUP по центру, включается как трубка; слева «select a page:» и страницы «N. PAGE» с подписью, справа —
// страница его контролами (Pick — слова, у длинных списков «◂▸»; Knob — шкала █ с числом; Flip — [■] on / off; Title —
// заголовок с чертой). Цифры 1–9 — страница, Tab — по кругу, ПКМ по контролу — сброс, Esc — закрыть.
// Хранилище общее со скином Space: StoreShared → sheet.py. Свои страницы: CORE (райс, бар, текст), COLORS (его трубки и
// схемы — omarchy-crt-colors), PROFILES (профили райса — пресеты Customizer, «save as»); наши home / deck / look / idle /
// shell — после его девяти.
PanelWindow {
    id: sheet

    signal done()
    visible: true
    screen: Ui.target
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: frame }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-prefs"
    WlrLayershell.keyboardFocus: Ui.touring ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
    HyprlandFocusGrab { active: !Ui.touring && !shut.running; windows: [sheet]; onCleared: sheet.close() }
    CrtPal { id: cp }

    readonly property var base: [["core", "Style, bar, font"], ["colors", "Tube or wallpaper"], ["screen", "Filter and glass"],
        ["windows", "Gaps and borders"], ["effects", "Blur and shadow"], ["animations", "Motion and curves"],
        ["input", "Mouse and keys"], ["system", "Display and clock"], ["profiles", "Save your setup"],
        ["home", "Home and widgets"], ["deck", "The deck"], ["bar", "Bar tray"], ["look", "Wallpaper look"],
        ["idle", "Lock and screensaver"], ["shell", "Parts of the rice"]]
    // страница — если в ней есть что показать (screen — у тем с трубкой, bar — у раскладки glyph-rice)
    readonly property var pages: base.filter(p => ["core", "colors", "profiles"].includes(p[0]) || (Schema.PAGES.find(x => x.id === p[0])?.columns ?? [])
        .some(col => col.some(sec => sec && sec.controls.some(c => Schema.shown(c, StoreShared.values, StoreShared.caps)))))
    property string tab: pages.some(p => p[0] === Ui.sheet) ? Ui.sheet : "core"
    readonly property int index: Math.max(0, pages.findIndex(p => p[0] === tab))
    readonly property var page: Schema.PAGES.find(p => p.id === tab)
    function step(d) { tab = pages[(index + d + pages.length) % pages.length][0] }

    property real t: 0
    Component.onCompleted: { StoreShared.refresh(); Sk.list = pickl; Sk.keys = keys; Sk.nav = nav; grow.start() }
    Binding {
        target: Sk
        property: "t"
        value: ({ bg: cp.bg, card: cp.bg, ink: cp.fg, dim: cp.dim, accent: cp.accent, line: cp.line, sel: cp.accent, font: cp.font,
                  head: cp.font, size: cp.size, caps: true, spacing: 1, radius: 0, border: 2, shadow: 0, popup: "completion", ring: cp.accent })
    }
    NumberAnimation { id: grow; target: sheet; property: "t"; to: 1; duration: 240; easing.type: Easing.OutCubic }
    SequentialAnimation {
        id: shut
        NumberAnimation { target: sheet; property: "t"; to: 0; duration: 160; easing.type: Easing.InCubic }
        ScriptAction { script: sheet.done() }
    }
    function close() { if (!shut.running) { grow.stop(); shut.start() } }
    function open() { shut.stop(); grow.start() }
    function toggle() { shut.running ? open() : close() }

    // ── его контролы ──
    component Caption: CrtType { readonly property CrtPal cp: CrtPal {}; pal: cp; width: 170; height: 22; caps: false; elide: Text.ElideRight }
    component Title: Item {
        id: title
        readonly property CrtPal cp: CrtPal {}  // внешние id во вложенных компонентах не видны
        property string text
        width: parent?.width ?? 280
        height: 22
        Rectangle { anchors.verticalCenter: parent.verticalCenter; x: tl.implicitWidth + 10; width: parent.width - x; height: 1; color: cp.low }
        CrtType { id: tl; pal: cp; height: parent.height; text: title.text; color: cp.accent }
    }
    component Pick: Item {
        id: pick
        readonly property CrtPal cp: CrtPal {}  // внешние id во вложенных компонентах не видны
        property string label
        property var options: []
        property string key
        property var fallback
        readonly property var raw: StoreShared.values[key]
        property var current: raw === "" || raw === undefined || raw === null ? (options.find(o => o.dflt)?.v ?? fallback) : raw
        readonly property bool many: options.length > 5
        readonly property int at: Math.max(0, options.findIndex(o => (o.v ?? o) === current))
        signal chose(var v)
        onChose: v => { if (key) StoreShared.set(key, v) }
        function next(d) { const o = options[(at + d + options.length) % options.length]; chose(o.v ?? o) }
        width: parent?.width ?? 340
        implicitHeight: Math.max(22, chips.height)
        Caption { text: pick.label }
        Flow {
            id: chips
            x: 170
            width: pick.width - 170
            spacing: 4
            Repeater {
                model: pick.many ? [pick.options[pick.at]] : pick.options
                Rectangle {
                    id: chip
                    required property var modelData
                    readonly property bool on: (modelData?.v ?? modelData) === pick.current
                    width: word.implicitWidth + 12 + (pick.many ? 26 : 0)
                    height: 22
                    color: on && !pick.many ? cp.accent : ca.containsMouse ? cp.low : "transparent"
                    CrtType { id: word; pal: cp; x: 6; height: parent.height; text: (chip.modelData?.l ?? chip.modelData ?? "") + (pick.many ? "  ▾" : ""); color: chip.on && !pick.many ? cp.bg : pick.many ? cp.accent : cp.dim }
                    MouseArea {
                        id: ca
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        // много вариантов: левый клик / Enter — выпадающий список, правый — предыдущий
                        function kbdPress() { pick.many ? Sk.list.open(chip, pick.options, pick.current, v => pick.chose(v), pick.label) : pick.chose(chip.modelData.v ?? chip.modelData) }
                        onClicked: m => { if (pick.many && m.button === Qt.RightButton) pick.next(-1); else kbdPress() }
                    }
                }
            }
        }
    }
    component Flip: Item {
        id: tg
        readonly property CrtPal cp: CrtPal {}  // внешние id во вложенных компонентах не видны
        property string label
        property string key
        property bool fallback: true
        property var raises
        readonly property bool on: !!(StoreShared.values[key] ?? fallback)
        width: parent?.width ?? 340
        implicitHeight: 22
        Caption { text: tg.label }
        Row {
            x: 170
            height: parent.height
            spacing: 6
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: box.implicitWidth + 4; height: parent.height - 4
                color: fa.containsMouse ? cp.low : "transparent"
                Text { id: box; anchors.centerIn: parent; text: tg.on ? "[■]" : "[ ]"; font.family: cp.font; font.pixelSize: cp.size; color: tg.on ? cp.accent : cp.dim }
            }
            CrtType { pal: cp; text: tg.on ? "on" : "off"; height: parent.height; color: tg.on ? cp.accent : cp.dim }
        }
        MouseArea {
            id: fa
            x: 166; width: 90; height: parent.height
            hoverEnabled: true
            function kbdPress() { flipIt() }
            onClicked: flipIt()
            function flipIt() {
                const r = tg.raises, next = {}
                next[tg.key] = !tg.on
                if (!tg.on && r && StoreShared.values[r.key] < r.min) next[r.key] = r.min
                StoreShared.setMany(next)
            }
        }
    }
    component Knob: Item {
        id: knob
        readonly property CrtPal cp: CrtPal {}  // внешние id во вложенных компонентах не видны
        property string key
        property string label
        property string unit
        property real from: 0
        property real to: 1
        property real step: 1
        property real fallback: from
        readonly property real v: StoreShared.values[key] ?? fallback
        readonly property int digits: (String(step).split(".")[1] ?? "").length
        readonly property real frac: Math.max(0, Math.min(1, (v - from) / (to - from)))
        function setFrac(x) { StoreShared.set(key, Number((Math.round((from + Math.max(0, Math.min(1, x)) * (to - from)) / step) * step).toFixed(digits))) }
        width: parent?.width ?? 340
        implicitHeight: 22
        Caption { text: knob.label }
        Item {
            id: track
            x: 170
            width: knob.width - 170 - readout.width - 8
            height: parent.height
            TextMetrics { id: cell; font.family: cp.font; font.pixelSize: cp.size; text: "█" }
            readonly property int cells: Math.max(4, Math.floor(width / Math.max(1, cell.advanceWidth)))
            readonly property int lit: Math.round(knob.frac * cells)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: cp.font; font.pixelSize: cp.size
                textFormat: Text.StyledText
                text: "<font color='" + cp.accent + "'>" + "█".repeat(track.lit) + "</font><font color='" + cp.low + "'>" + "░".repeat(track.cells - track.lit) + "</font>"
            }
            MouseArea {
                anchors.fill: parent
                function kbdAdjust(d) { knob.setFrac(knob.frac + d / Math.max(1, (knob.to - knob.from) / knob.step)) }
                function kbdPress() {}
                onPressed: m => knob.setFrac(m.x / width)
                onPositionChanged: m => { if (pressed) knob.setFrac(m.x / width) }
                onWheel: w => knob.setFrac(knob.frac + (w.angleDelta.y > 0 ? 1 : -1) / Math.max(1, (knob.to - knob.from) / knob.step))
            }
        }
        CrtType { id: readout; pal: cp; type: false; width: Math.max(36, implicitWidth); horizontalAlignment: Text.AlignRight; anchors.right: parent.right; height: parent.height; text: knob.v.toFixed(knob.digits) + knob.unit }
    }
    component Line: Item {
        id: line
        readonly property CrtPal cp: CrtPal {}  // внешние id во вложенных компонентах не видны
        property string text
        property string value
        property bool lit: false
        signal clicked(var mouse)
        width: parent?.width ?? 280
        height: 22
        readonly property color ink: la.containsMouse ? cp.bg : line.lit ? cp.accent : cp.fg
        Rectangle { anchors.fill: parent; color: la.containsMouse ? cp.accent : "transparent" }
        Text { x: 4; text: line.lit ? "▶" : ""; font.family: cp.font; font.pixelSize: cp.size; color: line.ink; anchors.verticalCenter: parent.verticalCenter }
        CrtType { pal: cp; caps: false; x: 24; width: parent.width - x - val.width - 10; height: parent.height; text: line.text; elide: Text.ElideRight; color: line.ink }
        CrtType { id: val; pal: cp; anchors.right: parent.right; anchors.rightMargin: 4; height: parent.height; text: line.value; color: la.containsMouse ? cp.bg : cp.dim }
        MouseArea { id: la; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: m => line.clicked(m); function kbdPress() { line.clicked({ button: Qt.LeftButton }) } }
    }

    MouseArea { anchors.fill: parent; onClicked: sheet.close() }

    CrtTube {
        id: frame
        pal: cp
        anchors.centerIn: parent
        width: Math.min(1180, sheet.width - 60)
        height: Math.min(sheet.height - 80, Math.max(menu.implicitHeight, content.implicitHeight + 70) + 70)
        t: sheet.t

        CrtBox { pal: cp; anchors.fill: parent; double: true; title: "setup"; note: "esc-end" }
        MouseArea { anchors.fill: parent; onPressed: m => { keys.forceActiveFocus(); m.accepted = false } }

        Column {
            id: menu
            x: 24; y: 28
            width: 250
            spacing: 2
            CrtType { pal: cp; text: "select a page:"; caps: false; color: cp.dim; height: 22 }
            Repeater {
                model: sheet.pages
                Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool on: sheet.tab === modelData[0]
                    width: menu.width
                    height: 34
                    color: on ? cp.accent : ra.containsMouse ? cp.low : "transparent"
                    CrtType { pal: cp; x: 8; y: 2; text: (row.index + 1) + ". " + row.modelData[0]; color: row.on ? cp.bg : cp.fg }
                    CrtType { pal: cp; x: 30; y: 17; caps: false; text: row.modelData[1]; font.pixelSize: cp.size - 3; color: row.on ? cp.bg : cp.dim }
                    MouseArea { id: ra; anchors.fill: parent; hoverEnabled: true; property int kbdOrder: 2000000 + row.index; onClicked: sheet.tab = row.modelData[0]; function kbdPress() { sheet.tab = row.modelData[0] } }
                }
            }
        }
        Rectangle { x: menu.x + menu.width + 18; y: 24; width: 1; height: frame.height - 48; color: cp.low }

        Flickable {
            x: menu.x + menu.width + 40
            y: 28
            width: frame.width - x - 28
            height: frame.height - 56
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Loader {
                id: content
                width: parent.width
                onLoaded: keys.forceActiveFocus()
                sourceComponent: ({ core: core, colors: colors, profiles: profiles })[sheet.tab] ?? pageView
            }
        }
    }

    // ── CORE: райс, бар, текст ──
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
    readonly property string riceNow: (riceHeads.find(h => riceVariants(h.label).some(r => String(r.value).split("/").pop().replace(/\.json$/, "") === StoreShared.active.preset))
        || riceHeads.find(h => slug(h.label) === slug(StoreShared.active.rice)) || riceHeads.find(h => h.label === "Retro CRT") || {}).label || ""
    // бар его трёх видов: default / boxes / zen — раскладки crt / crt-boxes / crt-zen
    property string barNow: ((StoreShared.lists.barLayouts || []).find(r => r.cur) || {}).label || ""
    Component {
        id: core
        Column {
            spacing: 6
            Title { width: 520; text: "style" }
            Pick {
                width: 520
                label: "Style"
                options: sheet.riceHeads.map(h => h.label)
                current: sheet.riceNow
                onChose: v => { const vs = sheet.riceVariants(v); if (v !== sheet.riceNow && vs.length) StoreShared.act("rice", [vs[0].value]) }
            }
            Pick {
                width: 520
                label: "Bar"
                options: [{ v: "crt-boxes", l: "boxes" }, { v: "crt", l: "default" }, { v: "crt-zen", l: "zen" }]
                current: sheet.barNow || "crt"
                onChose: v => { const r = (StoreShared.lists.barLayouts || []).find(x => x.label === v); sheet.barNow = v; if (r) StoreShared.act("barLayout", [r.value]) }
            }
            Item { width: 1; height: 8 }
            Title { width: 520; text: "type" }
            Knob { width: 520; label: "Text size"; key: "ui.size"; from: 10; to: 22; step: 1; fallback: 14 }
            Item {
                width: 520
                height: 180
                Caption { text: "Font" }
                GridView {
                    x: 170
                    width: parent.width - 170
                    height: parent.height
                    clip: true
                    cellWidth: width / 2
                    cellHeight: 22
                    model: StoreShared.lists.monoFonts || []
                    delegate: Rectangle {
                        required property string modelData
                        readonly property bool on: modelData === cp.font
                        width: GridView.view.cellWidth - 4
                        height: 22
                        color: on ? cp.accent : fh.containsMouse ? cp.low : "transparent"
                        Text { x: 6; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 10; elide: Text.ElideRight; text: parent.modelData; font.family: parent.modelData; font.pixelSize: 13; color: parent.on ? cp.bg : cp.fg }
                        MouseArea { id: fh; anchors.fill: parent; hoverEnabled: true; onClicked: StoreShared.set("ui.font", parent.modelData); function kbdPress() { StoreShared.set("ui.font", parent.modelData) } }
                    }
                }
            }
            CrtType { pal: cp; visible: Qt.fontFamilies().indexOf("Terminess Nerd Font Mono") === -1; caps: false; text: "tip: sudo pacman -S ttf-terminus-nerd for the real terminal font"; color: cp.dim; font.pixelSize: cp.size - 2 }
        }
    }

    // ── COLORS: его трубки и схемы, у каждой — 12 полосок акцента ──
    Component {
        id: colors
        Column {
            id: cc
            spacing: 10
            readonly property var slots: [9, 10, 11, 12, 13, 14, 1, 2, 3, 4, 5, 6]
            Title { width: 680; text: "tubes and schemes" }
            Grid {
                columns: 5
                spacing: 8
                Repeater {
                    model: StoreShared.lists.crtColors || []
                    Rectangle {
                        id: tile
                        required property var modelData
                        readonly property bool on: !!modelData.on
                        readonly property var pal: modelData.colors || []
                        readonly property int pick: modelData.slot ?? 9
                        width: 130
                        height: 96
                        color: "transparent"
                        border.width: on ? 2 : 1
                        border.color: on ? cp.accent : ta.containsMouse ? cp.line : cp.low
                        MouseArea {
                            id: ta; anchors.fill: parent; hoverEnabled: true
                            function kbdPress() { if (!tile.on) StoreShared.act("crtColors", [tile.modelData.id, String(tile.pick)]) }
                            onClicked: kbdPress()
                        }
                        Rectangle {
                            x: 6; y: 6
                            width: parent.width - 12
                            height: 30
                            color: tile.pal[0] ?? "#000"
                            Text { anchors.centerIn: parent; text: "> ready_"; font.family: cp.font; font.pixelSize: 13; color: tile.pal[tile.pick] ?? cp.accent }
                        }
                        CrtType { pal: cp; x: 6; y: 40; width: parent.width - 12; elide: Text.ElideRight; text: tile.modelData.name; color: tile.on ? cp.accent : cp.fg; font.pixelSize: cp.size - 2 }
                        Row {
                            x: 6; y: 66
                            spacing: 1
                            Repeater {
                                model: cc.slots
                                Rectangle {
                                    id: sw
                                    required property int modelData
                                    readonly property bool chosen: tile.pick === modelData
                                    width: 9
                                    height: chosen ? 22 : sa.containsMouse ? 18 : 14
                                    y: 22 - height
                                    color: tile.pal[modelData] ?? "#444"
                                    border.width: chosen ? 1 : 0
                                    border.color: cp.fg
                                    MouseArea { id: sa; anchors.fill: parent; anchors.topMargin: -(22 - parent.height); hoverEnabled: true; onClicked: StoreShared.act("crtColors", [tile.modelData.id, String(sw.modelData)]); function kbdPress() { StoreShared.act("crtColors", [tile.modelData.id, String(sw.modelData)]) } }
                                }
                            }
                        }
                    }
                }
            }
            CrtType { pal: cp; caps: false; width: 680; text: "Click a tile for its last accent or a swatch to pick one. The screen filter tints with the accent, set PHOSPHOR TINT to 0 on the screen page for full color."; color: cp.dim; font.pixelSize: cp.size - 2; wrapMode: Text.WordWrap; height: 40 }
        }
    }

    // ── PROFILES: профили райса (его сохранённые) и свои, «save as» ──
    Component {
        id: profiles
        Row {
            spacing: 24
            Column {
                width: 380
                Title { text: "saved" }
                Repeater {
                    model: StoreShared.lists.profiles || []
                    Line {
                        required property var modelData
                        property bool armed: false
                        lit: modelData.id === StoreShared.active.preset
                        text: modelData.name
                        value: armed ? "rclick again to delete" : modelData.mine ? "mine" : "his"
                        onClicked: m => {
                            if (m.button === Qt.LeftButton) return StoreShared.act("profile", [modelData.path])
                            if (!modelData.mine) return
                            if (armed) StoreShared.act("delete", [modelData.id])
                            armed = !armed
                        }
                    }
                }
            }
            Column {
                width: 300
                spacing: 8
                Title { text: "save as" }
                Rectangle {
                    width: 300; height: 26
                    color: "transparent"; border.width: 1; border.color: field.activeFocus ? cp.accent : cp.line
                    Text { x: 8; anchors.verticalCenter: parent.verticalCenter; text: ">"; color: cp.accent; font.family: cp.font; font.pixelSize: cp.size }
                    TextInput {
                        id: field
                        x: 24; width: parent.width - 32; anchors.verticalCenter: parent.verticalCenter
                        font.family: cp.font; font.pixelSize: cp.size; color: cp.fg
                        selectionColor: cp.accent; selectedTextColor: cp.bg
                        cursorDelegate: Rectangle { width: 9; color: cp.accent }
                        Text { visible: !field.text; text: "name"; color: cp.dim; font: field.font }
                        Keys.onEscapePressed: keys.forceActiveFocus()
                        onAccepted: { if (text.trim()) StoreShared.act("save", [text.trim()]); text = ""; keys.forceActiveFocus() }
                    }
                }
            }
        }
    }

    // ── страницы по схеме (его pageView) ──
    readonly property var screenPresets: [
        { l: "Terminal", v: { "crt.mono": 0.85, "crt.glow": 0.5, "crt.lines": 0.35, "crt.vignette": 0.5, "crt.corners": 0.5, "crt.bend": 0, "crt.grain": 0.4 } },
        { l: "Clean", v: { "crt.mono": 0.35, "crt.glow": 0.2, "crt.lines": 0.12, "crt.vignette": 0.2, "crt.corners": 0.2, "crt.bend": 0, "crt.grain": 0.1 } },
        { l: "Worn", v: { "crt.mono": 1, "crt.glow": 1, "crt.lines": 0.6, "crt.vignette": 0.9, "crt.corners": 1, "crt.bend": 0.3, "crt.grain": 0.9 } },
        { l: "Arcade", v: { "crt.mono": 0, "crt.glow": 0.8, "crt.lines": 0.5, "crt.vignette": 0.6, "crt.corners": 0.7, "crt.bend": 0.2, "crt.grain": 0.3 } }
    ]
    Component {
        id: pageView
        Column {
            spacing: 14
            Row {
                visible: sheet.tab === "screen"
                spacing: 6
                CrtType { pal: cp; width: 170; height: 22; caps: false; text: "Presets" }
                Repeater {
                    model: sheet.screenPresets
                    CrtButton { required property var modelData; pal: cp; label: modelData.l; onPressed: StoreShared.setMany(modelData.v) }
                }
            }
            Row {
                spacing: 32
                Repeater {
                    model: sheet.page?.columns ?? []
                    Column {
                        id: col
                        required property var modelData
                        readonly property var all: modelData.filter(s => !!s).reduce((a, s) => a.concat(s.controls), [])
                        width: all.some(c => c.type === "bezier") ? 520 : 380
                        visible: all.some(c => Schema.shown(c, StoreShared.values, StoreShared.caps))
                        spacing: 12
                        Repeater {
                            model: col.modelData.filter(s => !!s)
                            Column {
                                id: sec
                                required property var modelData
                                visible: modelData.controls.some(c => Schema.shown(c, StoreShared.values, StoreShared.caps))
                                width: col.width
                                spacing: 3
                                Title { text: sec.modelData.label }
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
                                        sourceComponent: ({ slider: slider, toggle: flip, choice: choice, bezier: bezier, animpreset: preset })[def.type] ?? null
                                        Component { id: slider; Knob { key: ctl.def.key; label: ctl.def.label; unit: ctl.def.unit; from: ctl.def.min; to: ctl.def.max; step: ctl.def.step; fallback: ctl.def.dflt ?? ctl.def.min } }
                                        Component { id: flip; Flip { key: ctl.def.key; label: ctl.def.label; raises: ctl.def.raises; fallback: ctl.def.dflt ?? true } }
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
    }

    // клавиатура: SheetKeys.js (Tab, [ ], 1–9, hjkl, ?) + KeyNav по строкам; выбор из многих — выпадающий список
    property bool help: false
    Item {
        id: keys
        focus: true
        Keys.onPressed: e => {
            if (!keys.activeFocus) return
            if (SheetKeys.handle(e, { list: pickl, nav: nav, tabs: sheet.pages.map(p => p[0]), go: t => sheet.tab = t, step: sheet.step,
                                      close: sheet.close, help: () => sheet.help = !sheet.help, helpOn: () => sheet.help }))
                e.accepted = true
        }
    }
    KeyNav { id: nav; anchors.fill: parent; z: 999; scope: frame; vim: false; active: !pickl.opened && !shut.running; ring: cp.accent; ringWidth: 2 }
    PickList { id: pickl }
    Rectangle {
        visible: sheet.help
        z: 4000
        readonly property var rows: [["TAB  [ ]  1-9", "PAGES"], ["ARROWS  H J K L", "MOVE"], ["ENTER  SPACE", "PRESS / OPEN LIST"], ["RIGHT CLICK", "PREVIOUS / DEFAULT"], ["ESC", "CLOSE"]]
        width: 360; height: rows.length * 24 + 20
        x: frame.x + (frame.width - width) / 2; y: frame.y + (frame.height - height) / 2
        color: cp.bg; border.width: 2; border.color: cp.accent
        Column { x: 14; y: 10
            Repeater { model: parent.parent.rows
                Row { required property var modelData; height: 24
                    Text { width: 180; text: modelData[0]; color: cp.accent; font.family: cp.font; font.pixelSize: cp.size; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: modelData[1]; color: cp.fg; font.family: cp.font; font.pixelSize: cp.size; anchors.verticalCenter: parent.verticalCenter } } } }
    }
}

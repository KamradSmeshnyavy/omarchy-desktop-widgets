import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons as Commons
import ".."
import "MotionShared.js" as Motion
import "Schema.js" as Schema
import "SheetKeys.js" as SheetKeys

// Скин modern панели настроек — по мотивам его Modern/settings (shell.qml, Themes.qml, SettingSaved.qml,
// github.com/elifouts/Dotfiles, GPL-3.0; облик — v2/settings-*.png; код свой): боковая панель матового стекла во всю
// высоту слева; сверху заголовок страницы и «Hyprland · Super+Alt+I», ряд вкладок-значков (текущая — акцентом);
// разделы — подпись капителью и скруглённая карточка со строками. Страницы:
// - Profile — стиль (райс), сохранённые профили ЭТОГО райса (его и свои; ПКМ дважды — удалить), новое имя и Save,
//   его пять видов бара мини-превью (раскладка + скин);
// - Themes — «Pywal» по обоям и его схемы (omarchy-modern-colors), у каждой 16 цветов, клик по цвету — акцент;
//   ниже обои его библиотеки по папкам с их палитрой: клик — поставить (при Pywal перекрашивает);
// - остальные — страницы схемы (окна, эффекты, анимации, ввод, система, наши home / deck / look / idle / shell):
//   ползунок — подпись, значение акцентом справа и полоска; переключатель — пилюля; выбор — сегменты или «‹ ›».
// Tab / Shift+Tab — вкладки, ПКМ по контролу — сброс, Esc — закрыть. Хранилище — StoreShared → sheet.py.
PanelWindow {
    id: sheet

    signal done()
    visible: true
    screen: Ui.target
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region { item: panel }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-prefs"
    WlrLayershell.keyboardFocus: Ui.touring ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
    HyprlandFocusGrab { active: !Ui.touring && !shut.running; windows: [sheet]; onCleared: sheet.close() }

    // цвета и шрифт стиля
    readonly property color fg: Commons.Color.foreground
    readonly property color bg: Commons.Color.background
    readonly property color accent: Commons.Color.accent
    function a(c, k) { return Qt.rgba(c.r, c.g, c.b, k) }
    readonly property string font: Qt.fontFamilies().indexOf("CodeNewRoman Nerd Font Propo") !== -1 ? "CodeNewRoman Nerd Font Propo"
        : Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : "monospace"

    readonly property var base: [["profile", "Profile", ""], ["themes", "Themes", ""], ["windows", "Windows", ""],
        ["effects", "Effects", ""], ["animations", "Animations", ""], ["input", "Input & cursor", ""],
        ["system", "General", ""], ["home", "Home", ""], ["deck", "Deck", ""], ["bar", "Bar", ""],
        ["look", "Look", ""], ["idle", "Idle", ""], ["shell", "Shell", ""]]
    readonly property var pages: base.filter(p => ["profile", "themes"].includes(p[0]) || (Schema.PAGES.find(x => x.id === p[0])?.columns ?? [])
        .some(col => col.some(sec => sec && sec.controls.some(c => Schema.shown(c, StoreShared.values, StoreShared.caps)))))
    property string tab: pages.some(p => p[0] === Ui.sheet) ? Ui.sheet : "profile"
    readonly property int index: Math.max(0, pages.findIndex(p => p[0] === tab))
    readonly property var page: Schema.PAGES.find(p => p.id === tab)
    function step(d) { tab = pages[(index + d + pages.length) % pages.length][0] }
    onTabChanged: flick.contentY = 0
    // openPrefsPage при открытой панели: клик по вкладке рвёт привязку tab к Ui.sheet
    Connections { target: Ui; function onSheetChanged() { if (sheet.pages.some(p => p[0] === Ui.sheet)) sheet.tab = Ui.sheet } }

    property real t: 0
    Component.onCompleted: { StoreShared.refresh(); Sk.list = pickl; Sk.keys = keys; Sk.nav = nav; grow.start() }
    Binding {
        target: Sk
        property: "t"
        value: ({ bg: sheet.bg, card: Qt.tint(sheet.bg, sheet.a(sheet.fg, 0.06)), ink: sheet.fg, dim: sheet.a(sheet.fg, 0.6), accent: sheet.accent,
                  line: sheet.a(sheet.fg, 0.18), sel: sheet.accent, font: sheet.font, head: sheet.font, size: 13, caps: false, spacing: 0,
                  radius: 9, border: 1, shadow: 0, popup: "list", ring: sheet.accent })
    }
    NumberAnimation { id: grow; target: sheet; property: "t"; to: 1; duration: 320; easing.type: Easing.OutCubic }
    SequentialAnimation {
        id: shut
        NumberAnimation { target: sheet; property: "t"; to: 0; duration: 200; easing.type: Easing.InCubic }
        ScriptAction { script: sheet.done() }
    }
    function close() { if (!shut.running) { grow.stop(); shut.start() } }
    function open() { shut.stop(); grow.start() }
    function toggle() { shut.running ? open() : close() }

    // ── его контролы ──
    component Label: Text {
        readonly property ModernPal s: ModernPal {}
        font.family: s.font; font.pixelSize: 14; color: s.fg; elide: Text.ElideRight
    }
    component Head: Text {
        readonly property ModernPal s: ModernPal {}
        font.family: s.font; font.pixelSize: 11; font.letterSpacing: 2; font.capitalization: Font.AllUppercase
        color: s.a(s.fg, 0.45); height: 30; verticalAlignment: Text.AlignBottom; bottomPadding: 8; leftPadding: 4
    }
    // карточка раздела: строки разделены тонкими линиями
    component Card: Rectangle {
        default property alias rows: col.data
        readonly property ModernPal s: ModernPal {}
        width: parent?.width ?? 560
        height: col.implicitHeight + 8
        radius: 12
        color: s.a(s.fg, 0.04)
        Column { id: col; x: 18; y: 4; width: parent.width - 36 }
    }
    component Rule: Rectangle { readonly property ModernPal s: ModernPal {}; width: parent?.width ?? 0; height: 1; color: s.a(s.fg, 0.06) }
    component Slide: Item {
        id: sl
        readonly property ModernPal s: ModernPal {}
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
        width: parent?.width ?? 520
        implicitHeight: 52
        Label { y: 10; width: parent.width - 80; text: sl.label }
        Text { anchors.right: parent.right; y: 10; text: sl.v.toFixed(sl.digits) + (sl.unit ? " " + sl.unit : ""); font.family: s.font; font.pixelSize: 13; color: s.accent }
        Rectangle {
            id: tr
            y: 36; width: parent.width; height: 4; radius: 2; color: s.a(s.fg, 0.1)
            Rectangle { width: Math.max(4, parent.width * sl.frac); height: parent.height; radius: 2; color: s.accent }
        }
        MouseArea {
            x: 0; y: 26; width: parent.width; height: 24
            function kbdAdjust(d) { sl.setFrac(sl.frac + d / Math.max(1, (sl.to - sl.from) / sl.step)) }
            function kbdPress() {}
            onPressed: m => sl.setFrac(m.x / width)
            onPositionChanged: m => { if (pressed) sl.setFrac(m.x / width) }
            onWheel: w => sl.setFrac(sl.frac + (w.angleDelta.y > 0 ? 1 : -1) / Math.max(1, (sl.to - sl.from) / sl.step))
        }
    }
    component Toggle: Item {
        id: tg
        readonly property ModernPal s: ModernPal {}
        property string label
        property string key
        property bool fallback: true
        property var raises
        readonly property bool on: !!(StoreShared.values[key] ?? fallback)
        width: parent?.width ?? 520
        implicitHeight: 44
        Label { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 70; text: tg.label }
        Rectangle {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: 38; height: 20; radius: 10
            color: tg.on ? s.accent : s.a(s.fg, 0.14)
            Behavior on color { ColorAnimation { duration: 160 } }
            Rectangle {
                width: 14; height: 14; radius: 7; y: 3
                x: tg.on ? parent.width - width - 3 : 3
                color: tg.on ? s.bg : s.a(s.fg, 0.7)
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }
        }
        MouseArea {
            anchors.fill: parent
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
    component Choice: Item {
        id: ch
        readonly property ModernPal s: ModernPal {}
        property string label
        property var options: []
        property string key
        property var fallback
        readonly property var raw: StoreShared.values[key]
        property var current: raw === "" || raw === undefined || raw === null ? (options.find(o => o.dflt)?.v ?? fallback) : raw
        readonly property bool many: options.length > 4
        readonly property int at: Math.max(0, options.findIndex(o => (o.v ?? o) === current))
        signal chose(var v)
        onChose: v => { if (key) StoreShared.set(key, v) }
        function next(d) { const o = options[(at + d + options.length) % options.length]; chose(o.v ?? o) }
        width: parent?.width ?? 520
        implicitHeight: many ? 44 : 78
        Label { y: ch.many ? 13 : 10; width: ch.many ? parent.width - 200 : parent.width; text: ch.label }
        // мало вариантов — его Segmented; много — кнопка «значение ⌄», клик / колесо — дальше
        Rectangle {
            visible: !ch.many
            y: 36; width: parent.width; height: 32; radius: 9
            color: ch.s.a(ch.s.fg, 0.05)
            Row {
                anchors.fill: parent; anchors.margins: 3
                Repeater {
                    model: ch.many ? [] : ch.options
                    Rectangle {
                        required property var modelData
                        readonly property bool on: (modelData?.v ?? modelData) === ch.current
                        width: (parent.width) / Math.max(1, ch.options.length); height: parent.height; radius: 7
                        color: on ? ch.s.a(ch.s.accent, 0.85) : "transparent"
                        Text { anchors.centerIn: parent; text: parent.modelData?.l ?? parent.modelData; font.family: ch.s.font; font.pixelSize: 12; color: parent.on ? ch.s.bg : ch.s.a(ch.s.fg, 0.7) }
                        MouseArea { anchors.fill: parent; onClicked: ch.chose(parent.modelData.v ?? parent.modelData); function kbdPress() { ch.chose(parent.modelData.v ?? parent.modelData) } }
                    }
                }
            }
        }
        Rectangle {
            visible: ch.many
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            width: dl.implicitWidth + 40; height: 32; radius: 9
            color: da.containsMouse ? ch.s.a(ch.s.fg, 0.12) : ch.s.a(ch.s.fg, 0.07)
            Text { id: dl; x: 14; anchors.verticalCenter: parent.verticalCenter; text: ch.options[ch.at]?.l ?? ch.options[ch.at] ?? ""; font.family: ch.s.font; font.pixelSize: 13; color: ch.s.fg }
            Text { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: ""; font.family: ch.s.font; font.pixelSize: 9; color: ch.s.a(ch.s.fg, 0.6) }
            // клик / Enter — выпадающий список (применяется выбранное), правый клик — предыдущий
            MouseArea { id: da; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
                function kbdPress() { Sk.list.open(parent, ch.options, ch.current, v => ch.chose(v), ch.label) }
                onClicked: m => { if (m.button === Qt.RightButton) ch.next(-1); else kbdPress() } }
        }
    }

    component MiniPill: Rectangle {
        id: mpill
        readonly property ModernPal s: ModernPal {}
        property color ink
        property int dots: 3
        property bool wide: false
        height: 18; radius: 6; color: ink
        width: prow.implicitWidth + 12
        Row {
            id: prow
            anchors.centerIn: parent; spacing: 4
            Rectangle { visible: mpill.wide; width: 40; height: 8; radius: 4; color: mpill.s.a(mpill.s.bg, 0.6); anchors.verticalCenter: parent.verticalCenter }
            Repeater { model: mpill.dots; Rectangle { width: 8; height: 8; radius: 4; color: mpill.s.a(mpill.s.bg, 0.6) } }
        }
    }

    MouseArea { anchors.fill: parent; onClicked: sheet.close() }

    // ── панель ──
    Rectangle {
        id: panel
        x: -width * (1 - sheet.t) * 0.15
        width: Math.min(640, sheet.width * 0.45)
        height: sheet.height
        opacity: sheet.t
        color: sheet.a(sheet.bg, 0.86)
        border.width: 1
        border.color: sheet.a(sheet.fg, 0.06)
        MouseArea { anchors.fill: parent; onPressed: m => { keys.forceActiveFocus(); m.accepted = false } }

        Text { x: 32; y: 22; text: (sheet.pages[sheet.index] ?? [])[1] ?? ""; font.family: sheet.font; font.pixelSize: 26; color: sheet.fg }
        Text { anchors.right: parent.right; anchors.rightMargin: 32; y: 32; text: "Hyprland · Super+Alt+I"; font.family: sheet.font; font.pixelSize: 11; color: sheet.a(sheet.fg, 0.4) }

        // вкладки-значки
        Flow {
            id: tabs
            x: 32; y: 72
            width: panel.width - 64
            spacing: 8
            Repeater {
                model: sheet.pages
                Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool on: sheet.tab === modelData[0]
                    width: (tabs.width - 8 * 6) / 7; height: 44; radius: 10
                    color: on ? sheet.a(sheet.accent, 0.55) : tha.containsMouse ? sheet.a(sheet.fg, 0.1) : sheet.a(sheet.fg, 0.05)
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Text { anchors.centerIn: parent; text: parent.modelData[2]; font.family: sheet.font; font.pixelSize: 17; color: parent.on ? sheet.fg : sheet.a(sheet.fg, 0.7) }
                    MouseArea { id: tha; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; property int kbdOrder: 2000000 + parent.index; onClicked: sheet.tab = parent.modelData[0]; function kbdPress() { sheet.tab = parent.modelData[0] } }
                }
            }
        }

        Flickable {
            id: flick
            x: 32
            y: tabs.y + tabs.height + 10
            width: panel.width - 64
            height: panel.height - y - 16
            contentHeight: content.implicitHeight + 24
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Loader {
                id: content
                width: parent.width
                onLoaded: keys.forceActiveFocus()
                sourceComponent: ({ profile: profilePage, themes: themesPage })[sheet.tab] ?? pageView
            }
        }
    }

    // ── PROFILE: стиль, профили этого райса, вид бара ──
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
    readonly property string riceNow: (riceHeads.find(h => slug(h.label) === slug(StoreShared.active.rice)) || riceHeads.find(h => h.label === "Modern") || {}).label || ""
    // его виды бара: раскладка и скин
    readonly property var bars: [
        { v: "modern", skin: "modern", l: "Default" }, { v: "modern-attached", skin: "modern-attached", l: "Attached" },
        { v: "modern-experimental", skin: "modern-attached", l: "Experimental" }, { v: "modern-full", skin: "modern-full", l: "Full" },
        { v: "modern-zen", skin: "modern", l: "Zen" }]
    property string barNow: ((StoreShared.lists.barLayouts || []).find(r => r.cur) || {}).label || "modern"

    Component {
        id: profilePage
        Column {
            spacing: 4
            Head { text: "style" }
            Card {
                Choice {
                    label: "Style"
                    options: sheet.riceHeads.map(h => h.label)
                    current: sheet.riceNow
                    onChose: v => { const vs = sheet.riceVariants(v); if (v !== sheet.riceNow && vs.length) StoreShared.act("rice", [vs[0].value]) }
                }
                Text {
                    width: parent.width; bottomPadding: 12; wrapMode: Text.WordWrap
                    text: "A style carries its own shell, bar and animations. Profiles below are variations of this style only."
                    font.family: sheet.font; font.pixelSize: 11; color: sheet.a(sheet.fg, 0.45)
                }
            }
            Head { text: "saved profiles" }
            Card {
                Repeater {
                    model: StoreShared.lists.profiles || []
                    Item {
                        id: pr
                        required property var modelData
                        required property int index
                        property bool armed: false
                        readonly property bool on: modelData.id === StoreShared.active.preset
                        width: parent.width; height: 52
                        Rule { visible: pr.index > 0 }
                        Rectangle { x: 2; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4; color: pr.on ? sheet.accent : sheet.a(sheet.fg, 0.25) }
                        Label { x: 22; anchors.verticalCenter: parent.verticalCenter; text: pr.modelData.name.replace(/^Modern /, ""); font.bold: pr.on }
                        Text {
                            anchors.right: parent.right; anchors.rightMargin: pr.modelData.mine ? 30 : 4; anchors.verticalCenter: parent.verticalCenter
                            text: pr.armed ? "right-click again to delete" : pr.on ? "Applied" : pr.modelData.mine ? "mine" : ""
                            font.family: sheet.font; font.pixelSize: 12; color: pr.armed ? Commons.Color.urgent : sheet.accent
                        }
                        Text { visible: pr.modelData.mine; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: ""; font.family: sheet.font; font.pixelSize: 13; color: sheet.a(sheet.fg, 0.45) }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            function kbdPress() { StoreShared.act("profile", [pr.modelData.path]) }
                            onClicked: m => {
                                if (m.button === Qt.LeftButton) return StoreShared.act("profile", [pr.modelData.path])
                                if (!pr.modelData.mine) return
                                if (pr.armed) StoreShared.act("delete", [pr.modelData.id])
                                pr.armed = !pr.armed
                            }
                        }
                    }
                }
                Item {
                    width: parent.width; height: 56
                    Rectangle {
                        y: 10; width: parent.width - 82; height: 36; radius: 9
                        color: sheet.a(sheet.fg, 0.05)
                        border.width: field.activeFocus ? 1 : 0; border.color: sheet.a(sheet.accent, 0.6)
                        TextInput {
                            id: field
                            x: 14; width: parent.width - 28; anchors.verticalCenter: parent.verticalCenter
                            font.family: sheet.font; font.pixelSize: 13; color: sheet.fg
                            selectionColor: sheet.accent; selectedTextColor: sheet.bg
                            Text { visible: !field.text; text: "New profile name"; color: sheet.a(sheet.fg, 0.35); font: field.font }
                            Keys.onEscapePressed: keys.forceActiveFocus()
                            onAccepted: save.go()
                        }
                    }
                    Rectangle {
                        id: save
                        function go() { if (field.text.trim()) StoreShared.act("save", [field.text.trim()]); field.text = ""; keys.forceActiveFocus() }
                        anchors.right: parent.right; y: 10; width: 70; height: 36; radius: 9
                        color: sva.containsMouse ? sheet.a(sheet.accent, 0.5) : sheet.a(sheet.accent, 0.3)
                        Text { anchors.centerIn: parent; text: "Save"; font.family: sheet.font; font.pixelSize: 13; color: sheet.fg }
                        MouseArea { id: sva; anchors.fill: parent; hoverEnabled: true; onClicked: save.go(); function kbdPress() { save.go() } }
                    }
                }
                Text {
                    width: parent.width; bottomPadding: 12; wrapMode: Text.WordWrap
                    text: "Saving keeps colors, wallpaper, bar and every tweak. Right-click your own profile twice to delete it."
                    font.family: sheet.font; font.pixelSize: 11; color: sheet.a(sheet.fg, 0.45)
                }
            }
            Head { text: "bar"; visible: StoreShared.active.rice === "modern" }
            Card {
                visible: StoreShared.active.rice === "modern"
                Text {
                    width: parent.width; topPadding: 14; bottomPadding: 6; horizontalAlignment: Text.AlignHCenter
                    text: (sheet.bars.find(b => b.v === sheet.barNow) || {}).l || ""; font.family: sheet.font; font.pixelSize: 14; color: sheet.fg
                }
                Repeater {
                    model: sheet.bars
                    Rectangle {
                        id: bv
                        required property var modelData
                        readonly property bool on: sheet.barNow === modelData.v
                        width: parent.width; height: 46; radius: 10
                        color: on ? sheet.a(sheet.fg, 0.1) : bva.containsMouse ? sheet.a(sheet.fg, 0.05) : "transparent"
                        readonly property color ink: on ? sheet.a(sheet.fg, 0.85) : sheet.a(sheet.fg, 0.4)
                        // мини-превью: три пилюли / одна / полоса
                        Rectangle { visible: bv.modelData.v === "modern-full"; x: 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 24; height: 18; radius: 6; color: bv.ink }
                        MiniPill { ink: bv.ink; visible: ["modern", "modern-attached"].includes(bv.modelData.v); x: 12; anchors.verticalCenter: parent.verticalCenter; wide: true; dots: 1 }
                        MiniPill { ink: bv.ink; visible: bv.modelData.v !== "modern-full"; anchors.centerIn: parent; dots: bv.modelData.v === "modern-zen" ? 4 : 5; wide: bv.modelData.v === "modern-experimental" }
                        MiniPill { ink: bv.ink; visible: ["modern", "modern-attached"].includes(bv.modelData.v); anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; dots: 3 }
                        Rectangle { visible: bv.modelData.v === "modern-attached" || bv.modelData.v === "modern-experimental"; y: 0; x: 12; width: parent.width - 24; height: 2; color: bv.ink; opacity: 0.6 }
                        MouseArea {
                            id: bva; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            function kbdPress() { clickIt() }
                            onClicked: clickIt()
                            function clickIt() { sheet.barNow = bv.modelData.v; const r = (StoreShared.lists.barLayouts || []).find(x => x.label === bv.modelData.v); if (r) StoreShared.act("modernBar", [r.value, bv.modelData.skin]) }
                        }
                    }
                }
                Item { width: 1; height: 10 }
            }
        }
    }

    // ── THEMES: Pywal и схемы, затем обои его библиотеки ──
    property string wallFolder: "all"
    Component {
        id: themesPage
        Column {
            id: tp
            spacing: 4
            readonly property var entries: StoreShared.lists.modernColors || []
            readonly property bool live: StoreShared.lists.theme === "modern-live"
            Head { text: "colors" }
            Card {
                Repeater {
                    model: tp.entries
                    Item {
                        id: te
                        required property var modelData
                        required property int index
                        readonly property bool on: tp.live && !!modelData.on
                        readonly property var pal: modelData.colors || []
                        readonly property int slot: modelData.slot ?? 9
                        width: parent.width; height: 60
                        Rule { visible: te.index > 0 }
                        Rectangle { x: 2; y: 14; width: 8; height: 8; radius: 4; color: te.on ? sheet.accent : sheet.a(sheet.fg, 0.25) }
                        Label { x: 22; y: 8; text: te.modelData.name; font.bold: te.on; width: 200 }
                        Text { anchors.right: parent.right; y: 10; text: te.on ? "Applied" : ""; font.family: sheet.font; font.pixelSize: 12; color: sheet.accent }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: StoreShared.act("modernColors", [te.modelData.id, String(te.slot)]); function kbdPress() { StoreShared.act("modernColors", [te.modelData.id, String(te.slot)]) } }
                        Row {
                            x: 22; y: 32
                            spacing: 3
                            Repeater {
                                model: 16
                                Rectangle {
                                    id: sw
                                    required property int index
                                    readonly property bool chosen: te.slot === index
                                    width: (te.width - 22 - 45) / 16; height: chosen ? 20 : swa.containsMouse ? 18 : 14
                                    y: 20 - height
                                    radius: 4
                                    color: te.pal[index] ?? "#444"
                                    border.width: chosen ? 2 : 0
                                    border.color: sheet.fg
                                    MouseArea { id: swa; anchors.fill: parent; anchors.topMargin: -(20 - parent.height); hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        function kbdPress() { StoreShared.act("modernColors", [te.modelData.id, String(sw.index)]) }
                                        onClicked: StoreShared.act("modernColors", [te.modelData.id, String(sw.index)]) }
                                }
                            }
                        }
                    }
                }
                Text {
                    width: parent.width; bottomPadding: 12; wrapMode: Text.WordWrap
                    text: "Pywal takes the colors from the wallpaper. Click a row for its colors, a swatch to make it the accent."
                    font.family: sheet.font; font.pixelSize: 11; color: sheet.a(sheet.fg, 0.45)
                }
            }
            Head { text: "wallpapers" }
            Card {
                id: wc
                readonly property var walls: StoreShared.lists.walls || []
                readonly property var folders: ["all", "favorites"].concat([...new Set(walls.map(w => w.theme))])
                readonly property var shown: walls.filter(w => sheet.wallFolder === "all" || (sheet.wallFolder === "favorites" ? w.fav : w.theme === sheet.wallFolder))
                readonly property string cur: (StoreShared.lists.modernState || {}).source || ""
                Flow {
                    width: parent.width; topPadding: 12; bottomPadding: 10
                    spacing: 6
                    Repeater {
                        model: wc.folders
                        Rectangle {
                            required property string modelData
                            readonly property bool on: sheet.wallFolder === modelData
                            width: fl.implicitWidth + 20; height: 26; radius: 8
                            color: on ? sheet.a(sheet.accent, 0.55) : fa.containsMouse ? sheet.a(sheet.fg, 0.1) : sheet.a(sheet.fg, 0.05)
                            Text { id: fl; anchors.centerIn: parent; text: parent.modelData; font.family: sheet.font; font.pixelSize: 12; color: sheet.fg }
                            MouseArea { id: fa; anchors.fill: parent; hoverEnabled: true; onClicked: sheet.wallFolder = parent.modelData; function kbdPress() { sheet.wallFolder = parent.modelData } }
                        }
                    }
                }
                Grid {
                    columns: 3
                    spacing: 8
                    bottomPadding: 14
                    Repeater {
                        model: wc.shown
                        Item {
                            id: wt
                            required property var modelData
                            readonly property bool on: wc.cur === modelData.path || wc.cur.endsWith("/" + modelData.name + ".jpg")
                            width: (wc.width - 36 - 16) / 3; height: width * 9 / 16 + 12
                            Rectangle {
                                id: thumb
                                width: parent.width; height: parent.width * 9 / 16; radius: 8
                                color: sheet.a(sheet.fg, 0.06)
                                clip: true
                                border.width: wt.on ? 2 : wta.containsMouse ? 1 : 0
                                border.color: wt.on ? sheet.accent : sheet.a(sheet.fg, 0.3)
                                Image { anchors.fill: parent; anchors.margins: parent.border.width; source: "file://" + wt.modelData.thumb; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 320 }
                                Text { visible: !!wt.modelData.fav; anchors.right: parent.right; anchors.rightMargin: 6; y: 4; text: ""; font.family: sheet.font; font.pixelSize: 11; color: sheet.accent }
                            }
                            // его полоска палитры под картинкой
                            Row {
                                y: thumb.height + 4
                                Repeater {
                                    model: wt.modelData.colors || []
                                    Rectangle { required property string modelData; width: wt.width / 16; height: 5; color: modelData }
                                }
                            }
                            MouseArea { id: wta; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: StoreShared.act("modernWall", [wt.modelData.path]); function kbdPress() { StoreShared.act("modernWall", [wt.modelData.path]) } }
                        }
                    }
                }
            }
        }
    }

    // ── страницы по схеме ──
    Component {
        id: pageView
        Column {
            spacing: 4
            Repeater {
                model: (sheet.page?.columns ?? []).reduce((a, col) => a.concat(col.filter(s => !!s)), [])
                Column {
                    id: sec
                    required property var modelData
                    visible: modelData.controls.some(c => Schema.shown(c, StoreShared.values, StoreShared.caps))
                    width: parent.width
                    spacing: 4
                    Head { text: sec.modelData.label }
                    Card {
                        Repeater {
                            model: sec.modelData.controls
                            Loader {
                                id: ctl
                                required property var modelData
                                readonly property var def: modelData
                                width: parent.width
                                height: item?.implicitHeight ?? 0
                                visible: Schema.shown(def, StoreShared.values, StoreShared.caps)
                                active: visible
                                sourceComponent: ({ slider: slider, toggle: toggle, choice: choice, bezier: bezier, animpreset: preset })[def.type] ?? null
                                Component { id: slider; Slide { key: ctl.def.key; label: ctl.def.label; unit: ctl.def.unit ?? ""; from: ctl.def.min; to: ctl.def.max; step: ctl.def.step; fallback: ctl.def.dflt ?? ctl.def.min } }
                                Component { id: toggle; Toggle { key: ctl.def.key; label: ctl.def.label; raises: ctl.def.raises; fallback: ctl.def.dflt ?? true } }
                                Component { id: choice; Choice { key: ctl.def.key; label: ctl.def.label; options: ctl.def.options } }
                                Component { id: bezier; SettingBezierShared {} }
                                Component {
                                    id: preset
                                    Choice {
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
    KeyNav { id: nav; anchors.fill: parent; z: 999; scope: panel; vim: false; active: !pickl.opened && !shut.running; ring: sheet.accent }
    PickList { id: pickl }
    Rectangle {
        visible: sheet.help
        z: 4000
        readonly property var rows: [["Tab  [ ]  1–9", "pages"], ["↑ ↓ ← →  h j k l", "move"], ["← →  on a slider", "step"], ["Enter  Space", "press · open a list"], ["right click", "previous · default"], ["Esc", "close"]]
        width: 340; height: rows.length * 22 + 20; radius: 12
        x: panel.x + (panel.width - width) / 2; y: panel.y + (panel.height - height) / 2
        color: sheet.bg; border.width: 1; border.color: sheet.accent
        Column { x: 14; y: 10
            Repeater { model: parent.parent.rows
                Row { required property var modelData; height: 22
                    Text { width: 160; text: modelData[0]; color: sheet.accent; font.family: sheet.font; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: modelData[1]; color: sheet.fg; font.family: sheet.font; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter } } } }
    }
}

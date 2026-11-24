.pragma library
// Схема панели Sheet — его shared/SchemaShared.js (github.com/elifouts/Dotfiles, GPL-3.0). У нас: без его страницы
// профиля, градиентной рамки, utilities.*, загрузочного экрана и темы курсора (у нас их нет); добавлены страницы
// наших настроек (home, deck, look, idle, shell) из прежней панели Prefs; опции, которых нет в этом Hyprland, скрыты
// (caps.missing — от sheet.py state).
.import "MotionShared.js" as Motion

function slider(key, label, min, max, step, unit, extra) {
    return Object.assign({ type: "slider", key: key, label: label, min: min, max: max, step: step, unit: unit || "" }, extra)
}
function toggle(key, label, extra) {
    return Object.assign({ type: "toggle", key: key, label: label }, extra)
}
function choice(key, label, options, extra) {
    return Object.assign({ type: "choice", key: key, label: label, options: options }, extra)
}
function color(key, label, extra) {
    return Object.assign({ type: "color", key: key, label: label }, extra)
}
function section(label, controls) {
    return { label: label, controls: controls }
}
function opt(v, l, extra) {
    return Object.assign({ v: v, l: l }, extra)
}

var ON = { eq: true }
var NOT_THEME = { key: "animation.preset", ne: "theme" }

// Retro CRT: его страница SCREEN (Retro/common/Schema.js) — ЭЛТ-шейдер и фильтр обоев; видна у тем с трубкой (caps.crt)
function crt(k, label, min, max, step, dflt) { return slider("crt." + k, label, min, max, step, "", { dflt: dflt, cap: "crt" }) }
function wall(k, label, min, max, step, dflt) { return slider("filter." + k, label, min, max, step, "", { dflt: dflt, cap: "crt" }) }

var PAGES = [
    {
        id: "screen", label: "Screen", icon: "",
        sections: [
            section("Tube", [
                toggle("crt.on", "Screen filter", { dflt: true, cap: "crt" }),
                crt("mono", "Phosphor tint", 0, 1, 0.05, 0.85),
                crt("glow", "Glow", 0, 1.5, 0.05, 0.5),
                crt("lines", "Scanlines", 0, 0.9, 0.05, 0.35)
            ]),
            section("Glass", [
                crt("vignette", "Vignette", 0, 1, 0.05, 0.5),
                crt("corners", "Round corners", 0, 1, 0.05, 0.5),
                crt("bend", "Curve", 0, 1, 0.05, 0),
                crt("grain", "Grain", 0, 1, 0.05, 0.4)
            ]),
            section("Wallpaper filter", [
                toggle("filter.on", "Wallpaper", { dflt: true, cap: "crt" }),
                choice("filter.tone", "Color", [opt("lines", "Lines", { dflt: true }), opt("tube", "Tube"), opt("palette", "Palette"), opt("source", "Source")], { cap: "crt", when: { key: "filter.on", eq: true } }),
                choice("filter.dither", "Dither", [opt("bayer", "Bayer", { dflt: true }), opt("fine", "Fine"), opt("halftone", "Halftone"), opt("diffuse", "Diffuse"), opt("none", "None")], { cap: "crt", when: { key: "filter.on", eq: true } }),
                wall("pixel", "Pixel size", 1, 6, 1, 2),
                wall("levels", "Levels", 2, 12, 1, 6),
                wall("contrast", "Contrast", 0, 1, 0.05, 0.5),
                wall("bright", "Brightness", 0.1, 1, 0.05, 0.4)
            ])
        ]
    },
    {
        id: "colors", label: "Colors", icon: "\uf1fc",
        themes: true,
        sections: []
    },
    {
        id: "windows", label: "Windows", icon: "\uf2d0",
        sections: [
            section("Spacing", [
                slider("config.general.gaps_in", "Inner gaps", 0, 30, 1, " px"),
                slider("config.general.gaps_out", "Outer gaps", 0, 60, 1, " px"),
                slider("config.general.gaps_workspaces", "Workspace gaps", 0, 60, 1, " px")
            ]),
            section("Borders", [
                slider("config.general.border_size", "Border width", 0, 8, 1, " px"),
                slider("config.decoration.rounding", "Corner rounding", 0, 30, 1, " px"),
                slider("config.decoration.rounding_power", "Corner smoothness", 2, 8, 0.5, "", { when: { key: "config.decoration.rounding", gt: 0 } })
            ]),
            section("Tiling", [
                choice("config.general.layout", "Layout", [opt("dwindle", "Dwindle"), opt("master", "Master")]),
                toggle("config.dwindle.preserve_split", "Keep split direction", { when: { key: "config.general.layout", eq: "dwindle" } }),
                toggle("config.dwindle.smart_split", "Split toward the cursor", { when: { key: "config.general.layout", eq: "dwindle" } }),
                toggle("config.dwindle.smart_resizing", "Smart resizing", { when: { key: "config.general.layout", eq: "dwindle" } }),
                slider("config.dwindle.default_split_ratio", "Default split ratio", 0.2, 1.8, 0.05, "", { when: { key: "config.general.layout", eq: "dwindle" } }),
                choice("config.dwindle.force_split", "New window opens", [
                    opt(0, "Follow mouse"), opt(1, "Left / top"), opt(2, "Right / bottom")], { when: { key: "config.general.layout", eq: "dwindle" } }),
                slider("config.master.mfact", "Master size", 0.1, 0.9, 0.05, "", { when: { key: "config.general.layout", eq: "master" } }),
                choice("config.master.orientation", "Master position", [
                    opt("left", "Left"), opt("right", "Right"), opt("top", "Top"), opt("bottom", "Bottom"), opt("center", "Center")],
                    { when: { key: "config.general.layout", eq: "master" } }),
                choice("config.master.new_status", "New windows become", [
                    opt("slave", "Stack"), opt("master", "Master")], { when: { key: "config.general.layout", eq: "master" } })
            ]),
            section("Opacity", [
                slider("config.decoration.active_opacity", "Active windows", 0.3, 1, 0.01),
                slider("config.decoration.inactive_opacity", "Inactive windows", 0.3, 1, 0.01),
                slider("config.decoration.fullscreen_opacity", "Fullscreen windows", 0.3, 1, 0.01)
            ]),
            section("Behavior", [
                toggle("config.general.resize_on_border", "Resize from borders"),
                slider("config.general.extend_border_grab_area", "Border grab area", 0, 40, 1, " px", { when: { key: "config.general.resize_on_border", eq: true } }),
                toggle("config.general.snap.enabled", "Snap floating windows"),
                slider("config.general.snap.window_gap", "Snap to windows within", 1, 40, 1, " px", { when: { key: "config.general.snap.enabled", eq: true } }),
                slider("config.general.snap.monitor_gap", "Snap to edges within", 1, 40, 1, " px", { when: { key: "config.general.snap.enabled", eq: true } }),
                toggle("config.misc.focus_on_activate", "Focus windows that ask"),
                toggle("config.binds.workspace_back_and_forth", "Same workspace key goes back"),
                toggle("config.misc.close_special_on_empty", "Close empty scratchpads"),
                choice("config.input.focus_on_close", "Focus after closing", [opt(0, "Next window"), opt(1, "Under cursor")])
            ])
        ]
    },
    {
        id: "effects", label: "Effects", icon: "\uf0d0",
        sections: [
            section("Blur", [
                toggle("config.decoration.blur.enabled", "Background blur"),
                slider("config.decoration.blur.size", "Size", 1, 20, 1, "", { when: { key: "config.decoration.blur.enabled", eq: true } }),
                slider("config.decoration.blur.passes", "Passes", 1, 8, 1, "", { when: { key: "config.decoration.blur.enabled", eq: true } }),
                slider("config.decoration.blur.vibrancy", "Vibrancy", 0, 1, 0.05, "", { when: { key: "config.decoration.blur.enabled", eq: true } }),
                slider("config.decoration.blur.brightness", "Brightness", 0.2, 1.5, 0.05, "", { when: { key: "config.decoration.blur.enabled", eq: true } }),
                slider("config.decoration.blur.contrast", "Contrast", 0.2, 1.5, 0.05, "", { when: { key: "config.decoration.blur.enabled", eq: true } }),
                slider("config.decoration.blur.noise", "Grain", 0, 0.1, 0.005, "", { when: { key: "config.decoration.blur.enabled", eq: true } }),
                toggle("config.decoration.blur.xray", "X-ray (blur the wallpaper only)", { when: { key: "config.decoration.blur.enabled", eq: true } }),
                toggle("config.decoration.blur.popups", "Blur menus and popups", { when: { key: "config.decoration.blur.enabled", eq: true } })
            ]),
            section("Shadow", [
                toggle("config.decoration.shadow.enabled", "Drop shadow"),
                slider("config.decoration.shadow.range", "Range", 0, 60, 1, " px", { when: { key: "config.decoration.shadow.enabled", eq: true } }),
                slider("config.decoration.shadow.render_power", "Falloff", 1, 4, 1, "", { when: { key: "config.decoration.shadow.enabled", eq: true } }),
                slider("config.decoration.shadow.scale", "Scale", 0.5, 1, 0.05, "", { when: { key: "config.decoration.shadow.enabled", eq: true } }),
                toggle("config.decoration.shadow.sharp", "Hard edges", { when: { key: "config.decoration.shadow.enabled", eq: true } })
            ]),
            section("Glow", [
                toggle("config.decoration.glow.enabled", "Window glow"),
                slider("config.decoration.glow.range", "Range", 0, 60, 1, " px", { when: { key: "config.decoration.glow.enabled", eq: true } }),
                slider("config.decoration.glow.render_power", "Falloff", 1, 4, 1, "", { when: { key: "config.decoration.glow.enabled", eq: true } })
            ]),
            section("Focus", [
                toggle("config.decoration.dim_inactive", "Dim inactive windows"),
                slider("config.decoration.dim_strength", "Dim strength", 0, 1, 0.05, "", { when: { key: "config.decoration.dim_inactive", eq: true } }),
                toggle("config.decoration.motion_blur.enabled", "Motion blur")
            ])
        ]
    },
    {
        id: "animations", label: "Animations", icon: "\uf0e7",
        sections: [
            section("Motion", [
                toggle("config.animations.enabled", "Animations"),
                { type: "animpreset", when: { key: "config.animations.enabled", eq: true } },
                slider("animation.speed", "Speed", 0.3, 2.5, 0.05, "×", { when: NOT_THEME }),
                choice("animation.window", "Windows", Motion.WINDOWS, { when: NOT_THEME }),
                choice("animation.workspace", "Workspaces", Motion.WORKSPACES, { when: NOT_THEME })
            ]),
            section("Curve", [{ type: "bezier", when: { key: "config.animations.enabled", eq: true } }]),
            section("Details", [
                toggle("config.misc.animate_manual_resizes", "Animate manual resizes"),
                toggle("config.misc.animate_mouse_windowdragging", "Animate window dragging")
            ])
        ]
    },
    {
        id: "input", label: "Input & cursor", icon: "\uf245",
        sections: [
            section("Mouse", [
                slider("config.input.sensitivity", "Sensitivity", -1, 1, 0.05),
                choice("config.input.accel_profile", "Acceleration", [
                    opt("adaptive", "Adaptive", { dflt: true }), opt("flat", "Flat")]),
                choice("config.input.follow_mouse", "Focus follows mouse", [
                    opt(0, "Off"), opt(1, "Always"), opt(2, "On click"), opt(3, "Loose")]),
                toggle("config.input.natural_scroll", "Natural scrolling"),
                slider("config.input.scroll_factor", "Scroll speed", 0.2, 3, 0.1, "×"),
                toggle("config.input.left_handed", "Left-handed")
            ]),
            section("Touchpad", [
                toggle("config.input.touchpad.natural_scroll", "Natural scrolling"),
                toggle("config.input.touchpad.tap_to_click", "Tap to click"),
                toggle("config.input.touchpad.tap_and_drag", "Tap and drag"),
                toggle("config.input.touchpad.disable_while_typing", "Disable while typing"),
                toggle("config.input.touchpad.middle_button_emulation", "Two-button middle click"),
                slider("config.input.touchpad.scroll_factor", "Scroll speed", 0.2, 3, 0.1, "×")
            ].map(function (c) { c.cap = "touchpad"; return c })),
            section("Gestures", [
                toggle("config.gestures.workspace_swipe_invert", "Natural swipe direction"),
                slider("config.gestures.workspace_swipe_distance", "Swipe distance", 100, 700, 10, " px"),
                toggle("config.gestures.workspace_swipe_create_new", "Swipe past the last workspace")
            ].map(function (c) { c.cap = "touchpad"; return c })),
            section("Keyboard", [
                slider("config.input.repeat_rate", "Repeat rate", 5, 80, 1, "/s"),
                slider("config.input.repeat_delay", "Repeat delay", 100, 800, 10, " ms")
            ]),
            section("Cursor behavior", [
                slider("config.cursor.inactive_timeout", "Hide when idle", 0, 15, 1, " s"),
                toggle("config.cursor.hide_on_key_press", "Hide while typing"),
                toggle("config.cursor.no_warps", "Never jump to windows"),
                choice("config.cursor.warp_on_change_workspace", "Jump on workspace change", [
                    opt(0, "Off"), opt(1, "On"), opt(2, "Force")]),
                choice("config.cursor.no_hardware_cursors", "Software cursor", [
                    opt(2, "Auto"), opt(0, "Never"), opt(1, "Always")]),
                slider("config.cursor.zoom_factor", "Screen magnifier", 1, 4, 0.25, "×")
            ])
        ]
    },
    {
        id: "system", label: "System", icon: "\uf013",
        sections: [
            section("Display", [
                choice("config.misc.vrr", "Variable refresh rate", [opt(0, "Off"), opt(1, "On"), opt(2, "Fullscreen")]),
                toggle("config.debug.vfr", "Save power when idle"),
                choice("config.render.direct_scanout", "Direct scanout", [opt(0, "Off"), opt(1, "On"), opt(2, "Auto")]),
                toggle("config.debug.overlay", "Show FPS overlay")
            ]),
            section("Behavior", [
                toggle("config.misc.middle_click_paste", "Middle-click paste"),
                toggle("config.misc.mouse_move_enables_dpms", "Wake on mouse move"),
                toggle("config.misc.key_press_enables_dpms", "Wake on key press"),
                toggle("config.misc.enable_anr_dialog", "Warn about frozen apps"),
                toggle("config.misc.mouse_move_focuses_monitor", "Mouse moves focus between monitors", { cap: "multimonitor" })
            ])
        ]
    },
    {
        id: "home", label: "Home", icon: "",
        sections: [
            section("Home screen", [
                toggle("w.home", "Home screen on an empty workspace", { dflt: false }),
                choice("w.homeLayout", "Layout", [opt("auto", "Auto"), opt("glyph", "Glyph"), opt("classic", "Classic"), opt("minimal", "Minimal")], { when: { key: "w.home", eq: true } }),
                choice("w.homeCards", "Cards", [opt("auto", "Auto"), opt("glyph", "Glyph"), opt("style", "Style")], { when: { key: "w.home", eq: true } }),
                slider("w.homeScale", "Scale", 0.5, 1.6, 0.05, "×", { dflt: 1, when: { key: "w.home", eq: true } }),
                toggle("w.homeGreeting", "Greeting", { when: { key: "w.home", eq: true } }),
                toggle("w.homeDate", "Date", { when: { key: "w.home", eq: true } }),
                toggle("w.homeMeta", "Week and battery", { when: { key: "w.home", eq: true } }),
                toggle("w.homeBlink", "Blinking colon", { dflt: false, when: { key: "w.home", eq: true } })
            ]),
            section("Desktop widgets", [
                toggle("w.desktopWidgets", "Widgets on the desktop"),
                toggle("w.clock", "Clock", { dflt: false }),
                choice("w.clockStyle", "Clock style", [opt("big", "Big"), opt("stacked", "Stacked"), opt("terminal", "Terminal"), opt("minimal", "Minimal"), opt("vitreus", "Vitreus"), opt("yami", "Yami"), opt("bruteon", "Bruteon")], { when: { key: "w.clock", eq: true } }),
                toggle("w.media", "Now playing")
            ])
        ]
    },
    {
        id: "deck", label: "Deck", icon: "",
        sections: [
            section("Deck", [
                toggle("w.deck", "Deck at the screen edge", { dflt: false }),
                choice("w.deckLayout", "Layout", [opt("auto", "Auto"), opt("panel", "Panel"), opt("compact", "Compact"), opt("full", "Full")], { when: { key: "w.deck", eq: true } }),
                choice("w.deckCards", "Cards", [opt("auto", "Auto"), opt("glyph", "Glyph"), opt("style", "Style")], { when: { key: "w.deck", eq: true } }),
                choice("w.deckTrigger", "Opens on", [opt("dwell", "Dwell"), opt("bump", "Bump")], { when: { key: "w.deck", eq: true } }),
                slider("w.deckDelay", "Delay", 0, 1000, 50, " ms", { dflt: 300, when: { key: "w.deck", eq: true } }),
                slider("w.deckScale", "Scale", 0.5, 1.6, 0.05, "×", { dflt: 1, when: { key: "w.deck", eq: true } })
            ])
        ]
    },
    {
        id: "bar", label: "Bar", icon: "",
        sections: [
            section("Tray", [
                toggle("bar.tray.wifi", "Wi-Fi", { cap: "glyphBar" }),
                toggle("bar.tray.bluetooth", "Bluetooth", { cap: "glyphBar" }),
                toggle("bar.tray.sound", "Sound", { cap: "glyphBar" }),
                toggle("bar.tray.battery", "Battery", { cap: "glyphBar" })
            ]),
            section("Window title", [
                toggle("bar.title", "Window title in the bar", { cap: "glyphBar" }),
                slider("bar.titleLength", "Title width", 100, 400, 10, " px", { cap: "glyphBar", dflt: 220, when: { key: "bar.title", eq: true } })
            ])
        ]
    },
    {
        id: "look", label: "Look", icon: "",
        sections: [
            section("Wallpaper look", [
                choice("look.look", "Look", [opt("color", "Colour"), opt("mono", "Mono"), opt("dots", "Dots")]),
                slider("look.pitch", "Dot size", 4, 32, 1, " px", { dflt: 10, when: { key: "look.look", ne: "color" } }),
                slider("look.bright", "Light", 10, 100, 5, "%", { dflt: 100, when: { key: "look.look", ne: "color" } })
            ])
        ]
    },
    {
        id: "idle", label: "Idle", icon: "",
        sections: [
            section("Idle", [
                slider("idle.screensaver", "Screensaver after", 0, 60, 1, " min", { dflt: 0 }),
                slider("idle.lock", "Lock after", 0, 120, 1, " min", { dflt: 0 })
            ])
        ]
    },
    {
        id: "shell", label: "Shell", icon: "",
        sections: [
            section("Parts of the rice", [
                choice("w.settingsPanel", "Super+M", [opt("auto", "Auto"), opt("drawer", "Drawer"), opt("quick", "Quick"), opt("surface", "Surface"), opt("unit3", "Unit-3"), opt("bruteon", "Bruteon"), opt("yami", "Yami"), opt("cozytile", "Cozytile"), opt("rumda", "Rumda"), opt("glassring", "Glass ring"), opt("instrument", "Instrument"), opt("space", "Space"), opt("crt", "Retro CRT"), opt("modern", "Modern")]),
                choice("w.dashStyle", "Dashboard", [opt("default", "Default"), opt("dotmatrix", "DOT-MATRIX"), opt("vitreus", "Vitreus"), opt("pencils", "Pencils"), opt("rumda", "Rumda"), opt("surface", "Surface"), opt("bruteon", "Bruteon"), opt("unit3", "Unit-3"), opt("yami", "Yami"), opt("cozytile", "Cozytile"), opt("glyph", "Glyph"), opt("space", "Space"), opt("crt", "Retro CRT"), opt("modern", "Modern")]),
                choice("w.powerStyle", "Power menu", [opt("auto", "Auto"), opt("edge", "Edge"), opt("glyph", "Glyph"), opt("cassini", "Cassini"), opt("cozytile", "Cozytile"), opt("dial", "Dial")]),
                choice("w.clipboardPanel", "Clipboard", [opt("auto", "Auto"), opt("stock", "Stock"), opt("glyph", "Glyph")]),
                choice("w.settingsSkin", "Settings sheet", [opt("auto", "Auto"), opt("space", "Space"), opt("vitreus", "Vitreus"), opt("crt", "Retro CRT"), opt("modern", "Modern"), opt("rumda", "Rumda"), opt("yami", "Yami"), opt("bruteon", "Bruteon"), opt("cozytile", "Cozytile"), opt("surface", "Surface"), opt("unit3", "Unit-3"), opt("dotmatrix", "DOT-MATRIX"), opt("glyph", "Glyph")]),
                choice("w.overviewStyle", "Overview", [opt("auto", "Auto"), opt("grid", "Grid"), opt("starmap", "3D star map"), opt("voyage", "Voyage"), opt("table", "Table"), opt("modern", "Modern")]),
                toggle("w.bootIntro", "Boot animation on login")
            ]),
            section("Pickers and screens", [
                choice("part.launcher", "Launcher", [opt("modern", "Modern"), opt("crt", "Retro CRT"), opt("space", "Space"), opt("glyph", "Glyph"), opt("dotmatrix", "DOT-MATRIX"), opt("unit3", "Unit-3"), opt("cozytile", "Cozytile"), opt("surface", "Surface"), opt("liquid", "Liquid"), opt("terminal", "Terminal"), opt("constellation", "Constellation"), opt("list", "Stock")]),
                choice("part.picker", "Wallpapers", [opt("modern", "Modern"), opt("crt", "Retro CRT"), opt("space", "Space"), opt("slices", "Slices"), opt("cards", "Cards"), opt("coverflow", "Coverflow"), opt("strip", "Strip"), opt("wide", "Wide"), opt("polaroid", "Polaroid"), opt("honeycomb", "Honeycomb"), opt("dots", "Dots"), opt("nier", "NieR"), opt("glyph", "Glyph")]),
                choice("part.lock", "Lock screen", [opt("modern", "Modern"), opt("crt", "Retro CRT"), opt("space", "Space"), opt("classic", "Classic"), opt("glyph", "Glyph"), opt("dotmatrix", "DOT-MATRIX"), opt("unit3", "Unit-3")])
            ])
        ]
    }
];

function shown(c, values, caps) {
    if (c.cap && !(caps && caps[c.cap])) return false
    if (c.key && caps && caps.missing && caps.missing.indexOf(c.key) >= 0) return false
    if (!c.when) return true
    var conds = c.when.key === undefined && c.when.any === undefined ? c.when : [c.when]
    for (var i = 0; i < conds.length; i++)
        if (!holds(conds[i], values)) return false
    return true
}

function holds(w, values) {
    if (w.any !== undefined) {
        for (var i = 0; i < w.any.length; i++)
            if (holds(w.any[i], values)) return true
        return false
    }
    var v = values[w.key]
    if (v === undefined || v === null) return false
    if (w.eq !== undefined) {
        if (typeof w.eq === "boolean") return !!v === w.eq
        return v === w.eq
    }
    if (w.ne !== undefined) return v !== w.ne
    if (w.gt !== undefined) return v > w.gt
    return !!v
}

function keys() {
    var out = ["animation.curve", "animation.preset", "animation.speed", "animation.window", "animation.workspace"];
    PAGES.forEach(function (p) {
        p.sections.forEach(function (s) {
            s.controls.forEach(function (c) { if (c.key) out.push(c.key); });
        });
    });
    return out;
}

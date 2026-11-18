import QtQuick

// Его Space/wallpaper/Terrain.qml (github.com/elifouts/Dotfiles, GPL-3.0) для звёздной карты voyage: пейзаж обоев,
// он же планета в космосе (rise / endR / kind). Земля — из .scene.json текущих обоев (World.land), а не из его
// настроек; parallax — 1. Шейдер — его terrain.frag (копия из плагина обоев).

ShaderEffect {
    property int ws: 1
    property real screenX: 0
    property real pan: (ws - 1) * 1 + screenX / 2000 + drift
    property real zoom: 1
    property real lift: 0
    property real glow: 0
    property real drift: 0
    property real skyFade: 1
    property real wipe: 0
    property real beneath: -1
    property vector4d view: Qt.vector4d(0, 0, 0, 0)
    property vector4d viewSize: Qt.vector4d(0, 0, 0, 0)
    property real rise: 0
    property real clear: 0
    property real orbit: 1
    property real endR: 0.09
    property vector4d sun: Qt.vector4d(-0.35, 0.6, 0.7, 0)
    property real kind: 0
    property vector4d moonEnd: Qt.vector4d(0, 0, 0, 0)
    property real seed: World.landSeed
    readonly property real aspect: width / Math.max(1, height)
    property bool asTheme: false
    property real hue: -1
    readonly property var pal: hue >= 0 ? World.palette(hue).colors : null
    property color bg: pal ? pal.color0 : Theme.bg
    property color accent: pal ? pal[asTheme ? "color" + Theme.slotOf("accent") : "color9"] : Theme.accent
    property color fg: pal ? (asTheme ? Theme.readable(pal.color7) : pal.color15) : Theme.fg
    property color tone: pal ? pal.color4 : Theme.c(4, "#24324f")
    property int fade: 0
    Behavior on bg { enabled: fade > 0; ColorAnimation { duration: fade; easing.type: Easing.InOutSine } }
    Behavior on accent { enabled: fade > 0; ColorAnimation { duration: fade; easing.type: Easing.InOutSine } }
    Behavior on fg { enabled: fade > 0; ColorAnimation { duration: fade; easing.type: Easing.InOutSine } }
    Behavior on tone { enabled: fade > 0; ColorAnimation { duration: fade; easing.type: Easing.InOutSine } }
    property color zenith: Theme.mix(bg, "#000000", 0.2)
    property color horizon: Theme.mix(accent, bg, 0.25)
    property color warm: Theme.mix(accent, "#ffd9b0", 0.6)
    property color far: Theme.mix(accent, bg, 0.55)
    property color near: Theme.mix(tone, "#0e1528", 0.88)
    property color moon: Theme.mix(fg, accent, 0.4)
    property color shade: Theme.mix(bg, "#000000", 0.5)
    property real moonless: 0
    property real relief: World.landV("relief", 0.4)
    property real landH: World.landV("height", 1)
    property real bases: World.landV("bases", 0.4)
    property real treeSize: World.landV("treeSize", 1)
    property real atlasSize: World.landV("atlasSize", 1)
    property real snow: World.landV("snow", 0.5)
    property real fleet: World.landV("fleet", 0.7)
    property real flora: World.landV("flora", 1)
    property real grassy: World.landV("grass", 1.5)
    property real rocks: World.landV("rocks", 0.4)
    property real haze: World.landV("haze", 0.5)
    property real variety: World.landV("variety", 0.35)
    property real starAmt: World.landV("stars", 1)
    property real starSize: World.landV("starSize", 1)
    property real galaxy: World.landV("galaxy", 0.25)
    property real galaxyTilt: World.landV("galaxyTilt", 20) * Math.PI / 180
    property real dusk: World.landV("dusk", 0.55)
    property real atlasGlow: World.landV("atlasGlow", 0.8)
    property real ships: World.landV("ships", 0.5)
    property bool atlasOk: true
    property real atlas: atlasOk && World.landV("atlas", 0) ? 1 : 0
    property real ship: World.landV("ship", 1) ? 1 : 0
    property real traffic: World.landV("traffic", 1) ? 1 : 0
    property real comet: World.landV("comets", 1)
    Behavior on atlas { NumberAnimation { duration: Theme.ms(700); easing.type: Easing.InOutSine } }
    Behavior on ship { NumberAnimation { duration: Theme.ms(400); easing.type: Easing.InOutSine } }
    Behavior on traffic { NumberAnimation { duration: Theme.ms(400); easing.type: Easing.InOutSine } }
    Behavior on comet { NumberAnimation { duration: Theme.ms(400); easing.type: Easing.InOutSine } }
    fragmentShader: Qt.resolvedUrl("terrain.frag.qsb")
}

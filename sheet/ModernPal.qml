import QtQuick
import qs.Commons as Commons

// Цвета и шрифт скина modern панели настроек: вложенные компоненты SheetModern не видят внешний id, у каждого — свой.
QtObject {
    readonly property color fg: Commons.Color.foreground
    readonly property color bg: Commons.Color.background
    readonly property color accent: Commons.Color.accent
    readonly property color urgent: Commons.Color.urgent
    readonly property string font: Qt.fontFamilies().indexOf("CodeNewRoman Nerd Font Propo") !== -1 ? "CodeNewRoman Nerd Font Propo"
        : Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : "monospace"
    function a(c, k) { return Qt.rgba(c.r, c.g, c.b, k) }
}

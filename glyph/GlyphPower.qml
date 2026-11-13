import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland




// Из glyph-rice (GPL-3.0). меню питания: Super+Esc. Экран почти чёрный, слева столбец слов Doto: выбранное крупно с красной точкой, остальные Mute.
// ↑↓ — слово плавно растёт и сжимается. Справа кольцо из 60 точек: аптайм (доля шестичасовой смены)
PanelWindow {
    id: root

    // меню выключения в стиле glyph: powerStyle "glyph" в widgets.json, открывается тем же host.powerOpen
    // (omarchy-shell widgets togglePower). Команды — как у PowerMenu.qml (стоковое System-меню Omarchy)
    required property var host
    readonly property bool open: host.powerOpen && host.value("powerStyle") === "glyph"

    property int sel: 0
    // слова — Doto, в ней нет кириллицы: подписи всегда английские, как у glyph-rice
    readonly property var items: [
        ["LOCK", "omarchy-system-lock"],
        ["SLEEP", "systemctl suspend"],
        ["SHUT DOWN", "omarchy-system shutdown"],
        ["REBOOT", "omarchy-system reboot"],
        ["LOG OUT", "omarchy-system logout"]
    ]
    property real uptime: 0
    Process {
        id: up
        command: ["cat", "/proc/uptime"]
        stdout: StdioCollector { onStreamFinished: root.uptime = parseFloat(text) || 0 }
    }
    onOpenChanged: if (open) { sel = 0; up.running = true; stage.forceActiveFocus() }
    function close() { host.powerOpen = false }
    function accept() {
        const cmd = items[sel][1]
        close()
        Quickshell.execDetached(["bash", "-c", cmd])
    }

    screen: host.focusedScreen
    visible: open
    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "omarchy-power"

    Rectangle {
        anchors.fill: parent
        color: GTheme.fade(GTheme.bg, 0.96)
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Stage {
        id: stage
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Up || e.key === Qt.Key_K) root.sel = (root.sel + 4) % 5;
            else if (e.key === Qt.Key_Down || e.key === Qt.Key_J || e.key === Qt.Key_Tab) root.sel = (root.sel + 1) % 5;
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.accept();
            else if (e.key === Qt.Key_Escape) root.close();
            else return;
            e.accepted = true;
        }

        Column {
            x: 240
            anchors.verticalCenter: parent.verticalCenter
            spacing: 26
            Repeater {
                model: root.items
                Row {
                    id: it
                    required property var modelData
                    required property int index
                    readonly property bool on: root.sel === index
                    spacing: 30
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: it.on
                        width: 30
                        height: 30
                        radius: 15
                        color: GTheme.accent
                    }
                    Num {
                        text: it.modelData[0]
                        font.pixelSize: it.on ? 168 : 66
                        color: it.on ? GTheme.fg : GTheme.mute
                        Behavior on font.pixelSize { NumberAnimation { duration: GTheme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: GTheme.glide } }
                        Behavior on color { ColorAnimation { duration: GTheme.t } }
                    }
                    HoverHandler { onHoveredChanged: if (hovered) root.sel = it.index }
                    TapHandler { onTapped: { root.sel = it.index; root.accept(); } }
                }
            }
        }

        Item {
            x: stage.width - 200 - 460
            anchors.verticalCenter: parent.verticalCenter
            width: 460
            height: 460
            Ring { anchors.fill: parent; n: 60; dot: 10; f: root.uptime / (6 * 3600) }
            Column {
                anchors.centerIn: parent
                Lb { anchors.horizontalCenter: parent.horizontalCenter; text: root.host.tr("uptime", "аптайм") }
                Num {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: lead + 10
                    bottomPadding: lead + 10
                    text: `${Math.floor(root.uptime / 3600)}:${String(Math.floor(root.uptime / 60) % 60).padStart(2, "0")}`
                    font.pixelSize: 110
                }
                Lb {
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property int n: Hyprland.toplevels.values.length
                    text: `${n} window${n === 1 ? "" : "s"} open`
                }
            }
        }

        Row {
            x: 240
            anchors { bottom: parent.bottom; bottomMargin: 70 }
            spacing: 34
            Lb { text: root.host.tr("↑↓ select", "↑↓ выбор") }
            Lb { text: root.host.tr("↵ confirm", "↵ выполнить") }
            Lb { text: root.host.tr("esc cancel", "esc отмена") }
        }
    }
}

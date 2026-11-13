import QtQuick



// Из glyph-rice (GPL-3.0). чип, как режимы в лаунчере: вкл. — белая пилюля и чёрный текст, выкл. — серый текст
Rectangle {
    property alias text: lb.text
    property bool on
    signal clicked

    width: lb.width + 32
    height: 36
    radius: 18
    color: on ? GTheme.fg : "transparent"
    Behavior on color { ColorAnimation { duration: GTheme.t } }

    Lb { id: lb; anchors.centerIn: parent; px: 11; color: parent.on ? GTheme.ink : GTheme.grey }
    TapHandler { onTapped: parent.clicked() }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
}

import QtQuick



// Из glyph-rice (GPL-3.0). тумблер: пилюля, выкл — серый кружок слева, подпись справа от него; вкл — белое выезжает на всю длину, точка у правого
// края, подпись переезжает влево и чернеет. Клик, пробел, ↵ — переключить; ← выкл, → вкл
Rectangle {
    id: root

    property bool on
    property string text
    signal flip

    width: Math.max(170, lab.implicitWidth + 96)
    height: 64
    radius: (32)
    color: GTheme.s2
    border { width: activeFocus ? 1 : 0; color: GTheme.fg }
    activeFocusOnTab: true
    Keys.onPressed: e => {
        if (e.key === Qt.Key_Space || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) flip();
        else if (e.key === Qt.Key_Left || e.key === Qt.Key_Right) { if (on !== (e.key === Qt.Key_Right)) flip(); }
        else return;
        e.accepted = true;
    }

    Rectangle {
        x: 6
        y: 6
        width: root.on ? root.width - 12 : height
        height: root.height - 12
        radius: (height / 2)
        color: root.on ? GTheme.fg : GTheme.mute
        Behavior on width { NumberAnimation { duration: GTheme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: GTheme.glide } }
        Behavior on color { ColorAnimation { duration: GTheme.t } }
        Rectangle {
            anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
            width: 12
            height: 12
            radius: 6
            color: root.on ? GTheme.ink : GTheme.s2
        }
    }
    Lb {
        id: lab
        x: root.on ? 30 : 76 // вкл — точка справа, подпись уступает ей место
        Behavior on x { NumberAnimation { duration: GTheme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: GTheme.glide } }
        anchors.verticalCenter: parent.verticalCenter
        text: root.text
        color: root.on ? GTheme.ink : root.activeFocus ? GTheme.fg : GTheme.grey
        Behavior on color { ColorAnimation { duration: GTheme.t } }
    }
    TapHandler { onTapped: root.flip() }
}

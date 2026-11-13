import QtQuick


// Из glyph-rice (GPL-3.0). пилюля поверх кадра: Surface с обводкой Raised, содержимое рядом по центру. Клик по ней не уходит в кадр под ней
Rectangle {
    default property alias content: row.data
    property alias spacing: row.spacing
    property real pad: 10

    width: row.width + pad * 2
    height: 56
    radius: height / 2
    color: GTheme.s1
    border { width: 1; color: GTheme.s2 }

    MouseArea { anchors.fill: parent }
    Row { id: row; anchors.centerIn: parent }
}

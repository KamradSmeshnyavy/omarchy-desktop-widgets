import QtQuick

// Плеер yami: графитовая панель 400 × 140 с рамкой в пиксель (текст 16 %) и жёсткой тенью 3 px, пиксельный Tiny5:
// «♫ трек — исполнитель», полосы визуализатора акцентом, линия прогресса акцентом, квадратные ячейки [<<] [>] [>>].
PlayerBase {
  id: p
  implicitWidth: 403; implicitHeight: 143
  readonly property string px: font("Tiny5", "monospace")
  readonly property color panel: Qt.rgba(bg.r * 0.85, bg.g * 0.85, bg.b * 0.85, 1)
  Rectangle { x: 3; y: 3; width: 400; height: 140; color: Qt.rgba(0, 0, 0, 0.55) }
  Rectangle {
    width: 400; height: 140; color: p.panel; border.width: 1; border.color: p.alpha(p.fg, 0.16)
    Text { x: 14; y: 12; width: 372; elide: Text.ElideRight; text: "♫ " + p.mpTitle + " — " + p.mpArtist; color: p.fg; font.family: p.px; font.pixelSize: 14 }
    Row {
      x: 14; y: 40; height: 50; spacing: 3
      Repeater { model: 40; Rectangle { width: 6; height: 4 + 44 * p.level(index, 40); anchors.bottom: parent ? parent.bottom : undefined; color: p.accent; opacity: 0.35 + 0.65 * p.level(index, 40) } }
    }
    Rectangle { x: 14; y: 98; width: 372; height: 2; color: p.alpha(p.fg, 0.12)
      Rectangle { width: parent.width * p.frac; height: 2; color: p.accent }
      MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: function(e) { p.seekAt(e.x, width) } } }
    Text { x: 14; y: 110; text: p.fmt(p.mpPosition) + " / " + p.fmt(p.mpLength); color: p.alpha(p.fg, 0.6); font.family: p.px; font.pixelSize: 10 }
    Row {
      anchors.right: parent.right; anchors.rightMargin: 14; y: 106; spacing: 4
      Repeater {
        model: [["<<", 0], [p.mpPlaying ? "||" : ">", 1], [">>", 2]]
        Rectangle {
          required property var modelData
          width: 30; height: 22; color: h.hovered || modelData[1] === 1 ? p.accent : "transparent"; border.width: 1; border.color: p.alpha(p.fg, 0.3)
          Text { anchors.centerIn: parent; text: modelData[0]; color: h.hovered || modelData[1] === 1 ? p.panel : p.fg; font.family: p.px; font.pixelSize: 10 }
          HoverHandler { id: h; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: p.act(modelData[1]) }
        }
      }
    }
  }
}

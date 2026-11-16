import QtQuick
import "../dotmatrix" as DotMatrix

// Плеер DOT-MATRIX и Glyph (в духе Nothing): чёрная панель 380 × 150 с тонкой рамкой, обложка — точечным экраном
// (DotScreen), название крупным точечным шрифтом, исполнитель Space Mono капителью, прогресс — ряд точек, красный
// LED «● PLAYING», кнопки — круги с тонкой рамкой. Цвета — DotMatrix.Palette.
PlayerBase {
  id: p
  implicitWidth: 380; implicitHeight: 150
  Rectangle {
    anchors.fill: parent; radius: 18; color: DotMatrix.Palette.bg; border.width: 1; border.color: DotMatrix.Palette.line
    DotMatrix.DotScreen { x: 14; y: 14; width: 122; height: 122; source: p.mpCoverUrl; pitch: 4; radius: 14 }
    Row {
      x: 150; y: 18; spacing: 6
      Rectangle { width: 6; height: 6; radius: 3; color: p.mpPlaying ? DotMatrix.Palette.signal : DotMatrix.Palette.muted; anchors.verticalCenter: parent.verticalCenter }
      Text { text: p.mpPlaying ? "PLAYING" : "PAUSED"; color: DotMatrix.Palette.muted; font.family: DotMatrix.Palette.fontMono; font.pixelSize: 9; font.letterSpacing: 1.6 }
    }
    Text { x: 150; y: 36; width: 216; elide: Text.ElideRight; text: p.mpTitle; color: DotMatrix.Palette.fg; font.family: DotMatrix.Palette.fontDot; font.pixelSize: 20 }
    Text { x: 150; y: 64; width: 216; elide: Text.ElideRight; text: p.mpArtist.toUpperCase(); color: DotMatrix.Palette.dim; font.family: DotMatrix.Palette.fontMono; font.pixelSize: 9; font.letterSpacing: 1.4 }
    Row {
      x: 150; y: 88; spacing: 3
      Repeater { model: 31; Rectangle { width: 4; height: 4; radius: 2; color: index / 31 <= p.frac ? DotMatrix.Palette.lit : DotMatrix.Palette.unlit } }
    }
    Row {
      x: 150; y: 104; spacing: 10
      Repeater {
        model: [["\u{F04AE}", 0], [p.mpPlaying ? "\u{F03E4}" : "\u{F040A}", 1], ["\u{F04AD}", 2]]
        Rectangle {
          required property var modelData
          width: 30; height: 30; radius: 15; color: h.hovered ? DotMatrix.Palette.fg : "transparent"; border.width: 1; border.color: DotMatrix.Palette.line
          Text { anchors.centerIn: parent; text: modelData[0]; color: h.hovered ? DotMatrix.Palette.bg : DotMatrix.Palette.fg; font.pixelSize: 15 }
          HoverHandler { id: h; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: p.act(modelData[1]) }
        }
      }
    }
    Text { anchors.right: parent.right; anchors.rightMargin: 16; y: 112; text: p.fmt(p.mpPosition); color: DotMatrix.Palette.muted; font.family: DotMatrix.Palette.fontMono; font.pixelSize: 10 }
  }
}

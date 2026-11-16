import QtQuick
import QtQuick.Effects

// Плеер Bruteon: плитка 360 × 150 цвета карточки с контуром и жёсткой тенью 5 × 5, обложка в плитке с тенью, жирное
// название, исполнитель, волна точек визуализатора (сыгранное — чернилами), время и плитки назад / пауза (лососевая) /
// вперёд с подъёмом при наведении.
PlayerBase {
  id: p
  implicitWidth: 366; implicitHeight: 156
  readonly property color ink: fg
  readonly property color card: dark ? mix(bg, fg, 0.07) : mix(bg, Qt.color("#ffffff"), 0.35)
  readonly property string mono: font("JetBrainsMono Nerd Font", "monospace")
  Rectangle { x: 5; y: 5; width: 360; height: 150; radius: 12; color: p.ink }
  Rectangle {
    width: 360; height: 150; radius: 12; color: p.card; border.width: 3; border.color: p.ink
    Item {
      x: 16; y: 16; width: 110; height: 110
      Rectangle { x: 3; y: 3; width: 110; height: 110; radius: 10; color: p.ink }
      Rectangle {
        width: 110; height: 110; radius: 10; color: Qt.tint(p.card, p.alpha(p.ink, 0.12)); border.width: 2.5; border.color: p.ink; clip: true
        Image { id: art; anchors.fill: parent; anchors.margins: 3; source: p.mpCoverUrl; fillMode: Image.PreserveAspectCrop; visible: false; layer.enabled: true }
        Rectangle { id: msk; anchors.fill: art; radius: 7; visible: false; layer.enabled: true }
        MultiEffect { anchors.fill: art; source: art; visible: art.status === Image.Ready; maskEnabled: true; maskSource: msk; maskThresholdMin: 0.5 }
        Text { anchors.centerIn: parent; visible: art.status !== Image.Ready; text: "\u{F075A}"; color: p.ink; opacity: 0.5; font.pixelSize: 34 }
      }
    }
    Column {
      x: 142; y: 18; width: 200; spacing: 3
      Text { width: parent.width; elide: Text.ElideRight; text: p.mpTitle; color: p.ink; font.family: p.mono; font.pixelSize: 13; font.bold: true }
      Text { width: parent.width; elide: Text.ElideRight; text: p.mpArtist; color: p.alpha(p.ink, 0.6); font.family: p.mono; font.pixelSize: 10 }
    }
    Row {
      x: 142; y: 66; spacing: 3
      Repeater { model: 24; Rectangle { width: 5; height: 4 + 12 * p.level(index, 24); radius: 2.5; anchors.verticalCenter: parent ? parent.verticalCenter : undefined; color: p.ink; opacity: index / 24 <= p.frac ? 1 : 0.3 } }
    }
    Text { x: 142; y: 118; text: p.fmt(p.mpPosition); color: p.ink; font.family: p.mono; font.pixelSize: 10; font.bold: true }
    Text { anchors.right: parent.right; anchors.rightMargin: 16; y: 118; text: p.fmt(p.mpLength); color: p.ink; font.family: p.mono; font.pixelSize: 10; font.bold: true }
    Row {
      x: 142 + 100 - width / 2; y: 106; spacing: 10
      Repeater {
        model: [["", 0, "#fbf3ee", 26], [p.mpPlaying ? "" : "", 1, "#ffb3a1", 32], ["", 2, "#fbf3ee", 26]]
        Item {
          id: b
          required property var modelData
          width: modelData[3]; height: modelData[3]
          anchors.verticalCenter: parent ? parent.verticalCenter : undefined
          readonly property real lift: tap.pressed ? 0 : hov.hovered ? 3 : 2
          Rectangle { x: 2; y: 2; width: b.width; height: b.height; radius: 8; color: p.ink }
          Rectangle { x: 2 - b.lift; y: 2 - b.lift; width: b.width; height: b.height; radius: 8; color: b.modelData[2]; border.width: 2; border.color: p.ink
            Text { anchors.centerIn: parent; text: b.modelData[0]; color: "#161110"; font.family: p.mono; font.pixelSize: 10 } }
          HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
          TapHandler { id: tap; onTapped: p.act(b.modelData[1]) }
        }
      }
    }
  }
}

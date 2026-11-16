import QtQuick
import QtQuick.Effects

// Плеер Rumda: песочная пилюля 380 × 96 (заливка — акцент со светлой вуалью, как его карточки), рамка 3 px чуть темнее,
// круглая обложка в двойном кольце, коричневый текст пиксельным Dogica, карамельные круглые кнопки.
PlayerBase {
  id: p
  implicitWidth: 380; implicitHeight: 96
  readonly property color sand: Qt.tint(accent, Qt.rgba(1, 1, 1, 0.45))
  readonly property color brown: Qt.darker(accent, 1.6)
  readonly property string px: font("Dogica Pixel", font("Terminess Nerd Font", "monospace"))
  Rectangle {
    anchors.fill: parent; radius: height / 2; color: p.sand; border.width: 3; border.color: Qt.tint(p.accent, Qt.rgba(1, 1, 1, 0.2))
    Item {
      x: 10; y: 10; width: 76; height: 76
      Rectangle { anchors.fill: parent; radius: 38; color: "transparent"; border.width: 3; border.color: p.brown }
      Rectangle { anchors.fill: parent; anchors.margins: 6; radius: 32; color: p.alpha(p.brown, 0.2); clip: true
        Image { id: art; anchors.fill: parent; source: p.mpCoverUrl; fillMode: Image.PreserveAspectCrop; visible: false; layer.enabled: true }
        Rectangle { id: msk; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
        MultiEffect { anchors.fill: parent; source: art; visible: art.status === Image.Ready; maskEnabled: true; maskSource: msk; maskThresholdMin: 0.5 }
        RotationAnimation on rotation { from: 0; to: 360; duration: 12000; loops: Animation.Infinite; running: p.mpPlaying && p.shown }
      }
    }
    Column {
      x: 100; y: 18; width: 150; spacing: 6
      Text { width: parent.width; elide: Text.ElideRight; text: p.mpTitle; color: p.brown; font.family: p.px; font.pixelSize: 10 }
      Text { width: parent.width; elide: Text.ElideRight; text: p.mpArtist; color: p.alpha(p.brown, 0.7); font.family: p.px; font.pixelSize: 8 }
      Rectangle { width: parent.width; height: 6; radius: 3; color: p.alpha(p.brown, 0.18)
        Rectangle { width: parent.width * p.frac; height: 6; radius: 3; color: p.brown } }
    }
    Row {
      anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 6
      Repeater {
        model: [["\u{F04AE}", 0, 30], [p.mpPlaying ? "\u{F03E4}" : "\u{F040A}", 1, 38], ["\u{F04AD}", 2, 30]]
        Rectangle {
          required property var modelData
          width: modelData[2]; height: width; radius: width / 2
          anchors.verticalCenter: parent ? parent.verticalCenter : undefined
          color: modelData[1] === 1 || h.hovered ? p.brown : "transparent"; border.width: 2; border.color: p.brown
          Text { anchors.centerIn: parent; text: modelData[0]; color: modelData[1] === 1 || h.hovered ? p.sand : p.brown; font.pixelSize: modelData[1] === 1 ? 18 : 14 }
          HoverHandler { id: h; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: p.act(modelData[1]) }
        }
      }
    }
  }
}

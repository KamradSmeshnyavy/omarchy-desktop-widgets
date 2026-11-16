import QtQuick
import QtQuick.Effects

// Плеер Vitreus: жидкое стекло 400 × 170 (полупрозрачная заливка под размытием Hyprland, блик сверху, ободок), круглая
// обложка в кольце из 48 полос визуализатора акцентом, название и исполнитель, волнистая линия прогресса, кнопки-капли.
PlayerBase {
  id: p
  implicitWidth: 400; implicitHeight: 170
  Rectangle {
    anchors.fill: parent; radius: 26; color: p.alpha(p.bg, 0.45); border.width: 1; border.color: p.alpha(p.fg, 0.28)
    Rectangle { x: 1; y: 1; width: parent.width - 2; height: parent.height * 0.45; radius: 25
      gradient: Gradient { GradientStop { position: 0; color: p.alpha("#ffffff", 0.16) } GradientStop { position: 1; color: "transparent" } } }
    Item {
      x: 16; y: 15; width: 140; height: 140
      Repeater {
        model: 48
        Rectangle {
          readonly property real a: index / 48 * Math.PI * 2
          readonly property real len: 6 + 14 * p.level(index, 48)
          width: 3; height: len; radius: 1.5; color: p.accent; opacity: 0.85
          x: 70 + Math.sin(a) * (52 + len / 2) - 1.5; y: 70 - Math.cos(a) * (52 + len / 2) - len / 2
          rotation: a * 180 / Math.PI
        }
      }
      Rectangle {
        anchors.centerIn: parent; width: 96; height: 96; radius: 48; color: p.alpha(p.fg, 0.1); clip: true
        Image { id: art; anchors.fill: parent; source: p.mpCoverUrl; fillMode: Image.PreserveAspectCrop; visible: false; layer.enabled: true }
        Rectangle { id: msk; anchors.fill: parent; radius: 48; visible: false; layer.enabled: true }
        MultiEffect { anchors.fill: parent; source: art; visible: art.status === Image.Ready; maskEnabled: true; maskSource: msk; maskThresholdMin: 0.5 }
      }
    }
    Column {
      x: 170; y: 28; width: 212; spacing: 5
      Text { width: parent.width; elide: Text.ElideRight; text: p.mpTitle; color: p.fg; font.pixelSize: 16; font.weight: 700 }
      Text { width: parent.width; elide: Text.ElideRight; text: p.mpArtist; color: p.alpha(p.fg, 0.7); font.pixelSize: 12 }
    }
    Canvas {
      x: 170; y: 82; width: 212; height: 16
      property real ph: 0
      NumberAnimation on ph { from: 0; to: Math.PI * 2; duration: 2000; loops: Animation.Infinite; running: p.mpPlaying && p.shown }
      onPhChanged: requestPaint()
      onPaint: { var c = getContext("2d"); c.reset(); var cut = width * p.frac; c.lineWidth = 2.5; c.lineCap = "round"
        c.strokeStyle = p.accent; c.beginPath(); for (var x = 0; x <= cut; x += 2) { var y = 8 + Math.sin(x / 6 + ph) * 3; if (x === 0) c.moveTo(x, y); else c.lineTo(x, y) } c.stroke()
        c.strokeStyle = Qt.rgba(p.fg.r, p.fg.g, p.fg.b, 0.22); c.beginPath(); c.moveTo(cut + 3, 8); c.lineTo(width, 8); c.stroke() }
      MouseArea { anchors.fill: parent; onClicked: function(e) { p.seekAt(e.x, width) } }
    }
    Row {
      x: 170; y: 112; spacing: 10
      Repeater {
        model: [["\u{F04AE}", 0, 34], [p.mpPlaying ? "\u{F03E4}" : "\u{F040A}", 1, 42], ["\u{F04AD}", 2, 34]]
        Rectangle {
          required property var modelData
          width: modelData[2]; height: width; radius: width / 2
          anchors.verticalCenter: parent ? parent.verticalCenter : undefined
          color: modelData[1] === 1 ? p.alpha(p.accent, h.hovered ? 0.9 : 0.7) : p.alpha(p.fg, h.hovered ? 0.22 : 0.1); border.width: 1; border.color: p.alpha(p.fg, 0.3)
          Text { anchors.centerIn: parent; text: modelData[0]; color: p.fg; font.pixelSize: modelData[1] === 1 ? 20 : 16 }
          HoverHandler { id: h; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: p.act(modelData[1]) }
        }
      }
    }
    Text { anchors.right: parent.right; anchors.rightMargin: 18; y: 124; text: p.fmt(p.mpPosition) + " / " + p.fmt(p.mpLength); color: p.alpha(p.fg, 0.6); font.pixelSize: 10 }
  }
}

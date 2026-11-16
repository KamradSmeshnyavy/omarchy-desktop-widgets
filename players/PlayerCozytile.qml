import QtQuick
import QtQuick.Effects

// Плеер Cozytile: тёмная карточка 380 × 128 со скруглением 10 цвета фона темы, сверху язычок «♫ now playing» с
// S-образными боками, как вкладки его бара; слева обложка со скруглением 8, справа название и исполнитель JetBrains Mono,
// тонкая полоса прогресса цветом выбора (magenta) и три значка без рамок.
PlayerBase {
  id: p
  implicitWidth: 380; implicitHeight: 152
  readonly property string mono: font("JetBrainsMono Nerd Font", "monospace")
  readonly property color sel: accent
  // язычок
  Item {
    x: 18; width: tabT.implicitWidth + 44; height: 26
    Canvas {
      anchors.fill: parent
      onPaint: { var c = getContext("2d"); c.reset(); c.fillStyle = p.bg; var w = width, h = height
        c.beginPath(); c.moveTo(0, h); c.bezierCurveTo(10, h, 10, 0, 22, 0); c.lineTo(w - 22, 0); c.bezierCurveTo(w - 10, 0, w - 10, h, w, h); c.closePath(); c.fill() }
      Connections { target: p; function onBgChanged() { parent.requestPaint() } }
    }
    Text { id: tabT; anchors.centerIn: parent; anchors.verticalCenterOffset: 2; text: "\u{F075A}  now playing"; color: p.sel; font.family: p.mono; font.pixelSize: 11 }
  }
  Rectangle {
    y: 24; width: 380; height: 128; radius: 10; color: p.bg
    Rectangle {
      x: 14; y: 14; width: 100; height: 100; radius: 8; color: p.alpha(p.fg, 0.08); clip: true
      Image { id: art; anchors.fill: parent; source: p.mpCoverUrl; fillMode: Image.PreserveAspectCrop; visible: false; layer.enabled: true }
      Rectangle { id: msk; anchors.fill: parent; radius: 8; visible: false; layer.enabled: true }
      MultiEffect { anchors.fill: parent; source: art; visible: art.status === Image.Ready; maskEnabled: true; maskSource: msk; maskThresholdMin: 0.5 }
      Text { anchors.centerIn: parent; visible: art.status !== Image.Ready; text: "\u{F075A}"; color: p.sel; font.pixelSize: 30 }
    }
    Column {
      x: 128; y: 18; width: 236; spacing: 4
      Text { width: parent.width; elide: Text.ElideRight; text: p.mpTitle; color: p.fg; font.family: p.mono; font.pixelSize: 14; font.bold: true }
      Text { width: parent.width; elide: Text.ElideRight; text: p.mpArtist; color: p.alpha(p.fg, 0.6); font.family: p.mono; font.pixelSize: 11 }
    }
    Rectangle {
      x: 128; y: 72; width: 236; height: 4; radius: 2; color: p.alpha(p.fg, 0.12)
      Rectangle { width: parent.width * p.frac; height: 4; radius: 2; color: p.sel }
      MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: function(e) { p.seekAt(e.x, width) } }
    }
    Text { x: 128; y: 82; text: p.fmt(p.mpPosition) + " / " + p.fmt(p.mpLength); color: p.alpha(p.fg, 0.5); font.family: p.mono; font.pixelSize: 10 }
    Row {
      anchors.right: parent.right; anchors.rightMargin: 16; y: 84; spacing: 18
      Repeater {
        model: [["\u{F04AE}", 0], [p.mpPlaying ? "\u{F03E4}" : "\u{F040A}", 1], ["\u{F04AD}", 2]]
        Text {
          required property var modelData
          text: modelData[0]; color: h.hovered ? p.sel : p.fg; font.pixelSize: modelData[1] === 1 ? 24 : 18
          anchors.verticalCenter: parent ? parent.verticalCenter : undefined
          HoverHandler { id: h; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: p.act(modelData[1]) }
        }
      }
    }
  }
}

import QtQuick

// Плеер Modern (по мотивам стиля Modern из elifouts/Dotfiles, GPL-3.0 — его Modern/music/shell.qml и v2/music-*.jpg):
// карточка матового стекла 360 × 350, скругление 14: сверху чип с именем плеера и точкой, справа значок; обложка 92 px
// со скруглением, название, исполнитель и альбом; тонкая шкала с временем по краям; ⏮, большая круглая ⏯ акцентом, ⏭;
// внизу визуализатор — столбики, окрашенные от акцента к тексту, справа тают в точки. Клик по шкале — перемотка.
PlayerBase {
  id: p
  implicitWidth: 360; implicitHeight: 350
  readonly property string mono: font("CodeNewRoman Nerd Font Propo", font("JetBrainsMono Nerd Font", "monospace"))

  Rectangle {
    anchors.fill: parent
    radius: 14
    color: p.alpha(p.bg, 0.72)
    border.width: 1
    border.color: p.alpha(p.fg, 0.08)
  }

  Rectangle {
    x: 22; y: 20
    width: chip.implicitWidth + 30; height: 26; radius: 13
    color: p.alpha(p.fg, 0.07)
    Rectangle { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; radius: 3; color: p.mpPlaying ? p.accent : p.alpha(p.fg, 0.4) }
    Text { id: chip; x: 24; anchors.verticalCenter: parent.verticalCenter; text: "Now playing"; font.family: p.mono; font.pixelSize: 12; color: p.alpha(p.fg, 0.8) }
  }
  Text { anchors.right: parent.right; anchors.rightMargin: 24; y: 22; text: "󰓇"; font.family: p.mono; font.pixelSize: 18; color: p.accent }

  Rectangle {
    id: art
    x: 22; y: 62; width: 92; height: 92; radius: 12
    color: p.alpha(p.fg, 0.08)
    clip: true
    Image { anchors.fill: parent; source: p.mpCoverUrl; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 184 }
  }
  Column {
    x: art.x + art.width + 16; anchors.verticalCenter: art.verticalCenter
    width: p.width - x - 22
    spacing: 4
    Text { width: parent.width; elide: Text.ElideRight; text: p.mpTitle || "Nothing playing"; font.family: p.mono; font.pixelSize: 17; color: p.fg }
    Text { width: parent.width; elide: Text.ElideRight; text: p.mpArtist; font.family: p.mono; font.pixelSize: 13; color: p.alpha(p.fg, 0.65) }
  }

  Item {
    x: 22; y: 176; width: p.width - 44; height: 30
    Rectangle {
      width: parent.width; height: 3; radius: 1.5; color: p.alpha(p.fg, 0.12)
      Rectangle { height: parent.height; radius: parent.radius; color: p.alpha(p.fg, 0.8); width: parent.width * p.frac }
    }
    Text { y: 12; text: p.fmt(p.mpPosition); font.family: p.mono; font.pixelSize: 11; color: p.alpha(p.fg, 0.5) }
    Text { y: 12; anchors.right: parent.right; text: p.fmt(p.mpLength); font.family: p.mono; font.pixelSize: 11; color: p.alpha(p.fg, 0.5) }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: function(m) { p.seekAt(m.x, width) } }
  }

  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    y: 216
    spacing: 28
    Text { anchors.verticalCenter: parent.verticalCenter; text: "󰒮"; font.family: p.mono; font.pixelSize: 20; color: p.fg
      MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: p.prevTrack() } }
    Rectangle {
      width: 52; height: 52; radius: 26
      color: pa.containsMouse ? Qt.lighter(p.accent, 1.12) : p.accent
      Text { anchors.centerIn: parent; text: p.mpPlaying ? "󰏤" : "󰐊"; font.family: p.mono; font.pixelSize: 24; color: p.bg }
      MouseArea { id: pa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: p.playPause() }
    }
    Text { anchors.verticalCenter: parent.verticalCenter; text: "󰒭"; font.family: p.mono; font.pixelSize: 20; color: p.fg
      MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: p.nextTrack() } }
  }

  // визуализатор: 36 столбиков, низкие — точки
  Row {
    x: 22; y: 290
    width: p.width - 44
    height: 36
    spacing: 4
    Repeater {
      model: 36
      Item {
        required property int index
        readonly property real v: p.level(index, 36)
        width: (p.width - 44 - 35 * 4) / 36; height: 36
        Rectangle {
          anchors.bottom: parent.bottom
          width: parent.width
          height: Math.max(width, 36 * parent.v)
          radius: width / 2
          color: p.mix(p.accent, p.fg, parent.index / 36)
          opacity: 0.35 + 0.65 * parent.v
        }
      }
    }
  }
}

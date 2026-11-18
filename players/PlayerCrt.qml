import QtQuick
import ".."

// Плеер Retro CRT (по мотивам стиля Retro из elifouts/Dotfiles, GPL-3.0 — его common/MediaCard.qml и виджет музыки
// с retro/widgets-plain.png): двойная рамка «NOW PLAYING» 460 × 236 на фоне темы; сверху — визуализатор: столбики
// из клеток, отражённые вверх и вниз от средней черты, как у него на столе; ниже — обложка 92 px в рамке, название
// акцентом, исполнитель, шкала из клеток █/░ (клик — перемотать) со временем и кнопки |◀ ▌▌ ▶| в рамках.
PlayerBase {
  id: p
  implicitWidth: 460; implicitHeight: 254
  CrtPal { id: cp }

  CrtBox { pal: cp; anchors.fill: parent; anchors.topMargin: 10; anchors.bottomMargin: 8; double: true; title: "now playing"; note: p.mpPlaying ? "play" : "pause" }

  // визуализатор: 40 столбиков, клетки 3 px через 1, симметрично от середины
  Item {
    id: viz
    x: 20; y: 30; width: p.width - 40; height: 52
    readonly property int n: 40
    Rectangle { y: viz.height / 2; width: viz.width; height: 1; color: cp.low }
    Repeater {
      model: viz.n
      Item {
        required property int index
        readonly property real v: p.level(index, viz.n)
        readonly property int cells: Math.max(1, Math.round(v * 6))
        x: index * (viz.width / viz.n); width: viz.width / viz.n - 3; height: viz.height
        Repeater {
          model: parent.cells * 2
          Rectangle {
            required property int index
            readonly property int k: Math.floor(index / 2)
            width: parent.width; height: 3
            y: index % 2 ? viz.height / 2 + 2 + k * 4 : viz.height / 2 - 5 - k * 4
            color: k === 0 ? cp.accent : cp.a(cp.accent, 0.7 - k * 0.09)
          }
        }
      }
    }
  }

  Rectangle {
    id: art
    x: 20; y: 94; width: 92; height: 92
    color: cp.low
    Text { anchors.centerIn: parent; visible: cover.status !== Image.Ready; text: "󰝚"; color: cp.accent; font.family: cp.font; font.pixelSize: 28 }
    Image { id: cover; anchors.fill: parent; source: p.mpCoverUrl; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 184 }
    Rectangle { anchors.fill: parent; color: "transparent"; border.width: 1; border.color: cp.line }
  }
  Column {
    x: art.x + art.width + 14; y: art.y + 2
    width: p.width - x - 20
    spacing: 4
    CrtType { pal: cp; caps: false; width: parent.width; elide: Text.ElideRight; text: p.mpTitle || "no signal"; color: p.mpTitle ? cp.accent : cp.dim; font.pixelSize: cp.size + 2 }
    CrtType { pal: cp; caps: false; width: parent.width; elide: Text.ElideRight; text: p.mpArtist || "nothing playing" }
    Item {
      width: parent.width; height: 20
      Item {
        id: track
        width: parent.width - time.implicitWidth - 8; height: parent.height
        TextMetrics { id: cw; font.family: cp.font; font.pixelSize: cp.size; text: "█" }
        readonly property int cells: Math.max(4, Math.floor(width / Math.max(1, cw.advanceWidth)))
        readonly property int lit: Math.round(p.frac * cells)
        Text {
          anchors.verticalCenter: parent.verticalCenter
          font.family: cp.font; font.pixelSize: cp.size
          textFormat: Text.StyledText
          text: "<font color='" + cp.accent + "'>" + "█".repeat(track.lit) + "</font><font color='" + cp.low + "'>" + "░".repeat(track.cells - track.lit) + "</font>"
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: function(m) { p.seekAt(m.x, width) } }
      }
      CrtType { id: time; type: false; pal: cp; anchors.right: parent.right; height: parent.height; text: p.fmt(p.mpPosition) + "/" + p.fmt(p.mpLength); color: cp.dim; font.pixelSize: cp.size - 2 }
    }
    Row {
      spacing: 6
      CrtButton { pal: cp; label: "|◀"; onPressed: p.prevTrack() }
      CrtButton { pal: cp; label: p.mpPlaying ? "▌▌" : " ▶ "; primary: p.mpPlaying; onPressed: p.playPause() }
      CrtButton { pal: cp; label: "▶|"; onPressed: p.nextTrack() }
    }
  }
}

import QtQuick

// Карточка «сейчас играет» Retro CRT (его Retro/common/MediaCard.qml, elifouts/Dotfiles, GPL-3.0): обложка 92 px в
// рамке, название акцентом, артист, шкала из клеток █/░ с временем «1:31/3:26», кнопки |◀ ▌▌ ▶|. Без плеера —
// «no signal». s — масштаб. Шкала тянется мышью (перемотка), колесо — нет.
Item {
  id: card
  property var pal
  property var player: null
  property bool live: true
  property real s: 1
  implicitHeight: Math.max(art.height, info.implicitHeight)
  height: implicitHeight

  readonly property real len: player && player.length > 0 ? player.length : 0
  property real pos: 0
  Timer { interval: 1000; repeat: true; running: card.live && !!card.player && card.player.isPlaying; triggeredOnStart: true; onTriggered: card.pos = card.player ? card.player.position : 0 }
  onPlayerChanged: pos = player ? player.position : 0
  function clock(sec) { sec = Math.max(0, Math.floor(sec)); return Math.floor(sec / 60) + ":" + String(sec % 60).padStart(2, "0") }

  Rectangle {
    id: art
    anchors.verticalCenter: parent.verticalCenter
    width: 92 * card.s; height: width
    color: card.pal.low
    Text { anchors.centerIn: parent; visible: cover.status !== Image.Ready; text: "󰝚"; color: card.pal.accent; font.family: card.pal.font; font.pixelSize: 28 * card.s }
    Image {
      id: cover
      anchors.fill: parent
      source: card.player && card.player.trackArtUrl ? card.player.trackArtUrl : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      sourceSize.width: 184
    }
    Rectangle { anchors.fill: parent; color: "transparent"; border.width: 1; border.color: card.pal.line }
  }

  Column {
    id: info
    anchors.left: art.right; anchors.leftMargin: 12 * card.s
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2 * card.s

    CrtType { pal: card.pal; caps: false; width: parent.width; elide: Text.ElideRight; text: card.player ? (card.player.trackTitle || "unknown") : "no signal"; font.pixelSize: (card.pal.size + 2) * card.s; color: card.player ? card.pal.accent : card.pal.dim }
    CrtType { pal: card.pal; caps: false; width: parent.width; elide: Text.ElideRight; text: card.player ? (card.player.trackArtist || "") : "nothing playing"; font.pixelSize: card.pal.size * card.s }
    Item {
      visible: !!card.player
      width: parent.width; height: 20 * card.s
      Item {
        id: track
        width: parent.width - time.implicitWidth - 8; height: parent.height
        TextMetrics { id: cellW; font.family: card.pal.font; font.pixelSize: card.pal.size * card.s; text: "█" }
        readonly property int cells: Math.max(4, Math.floor(width / Math.max(1, cellW.advanceWidth)))
        readonly property int lit: card.len > 0 ? Math.round(Math.max(0, Math.min(1, card.pos / card.len)) * cells) : 0
        Text {
          anchors.verticalCenter: parent.verticalCenter
          font.family: card.pal.font; font.pixelSize: card.pal.size * card.s
          textFormat: Text.StyledText
          text: "<font color='" + card.pal.accent + "'>" + "█".repeat(track.lit) + "</font><font color='" + card.pal.low + "'>" + "░".repeat(track.cells - track.lit) + "</font>"
        }
        MouseArea {
          anchors.fill: parent
          function seek(mx) { if (card.player && card.player.canSeek && card.len > 0) { card.player.position = Math.max(0, Math.min(1, mx / width)) * card.len; card.pos = card.player.position } }
          onPressed: function(m) { seek(m.x) }
          onPositionChanged: function(m) { if (pressed) seek(m.x) }
        }
      }
      CrtType { id: time; type: false; pal: card.pal; anchors.right: parent.right; height: parent.height; text: card.clock(card.pos) + "/" + card.clock(card.len); font.pixelSize: (card.pal.size - 2) * card.s; color: card.pal.dim }
    }
    Row {
      visible: !!card.player
      spacing: 6 * card.s
      CrtButton { pal: card.pal; label: "|◀"; height: 22 * card.s; onPressed: if (card.player && card.player.canGoPrevious) card.player.previous() }
      CrtButton { pal: card.pal; label: card.player && card.player.isPlaying ? "▌▌" : " ▶ "; height: 22 * card.s; onPressed: if (card.player && card.player.canTogglePlaying) card.player.togglePlaying() }
      CrtButton { pal: card.pal; label: "▶|"; height: 22 * card.s; onPressed: if (card.player && card.player.canGoNext) card.player.next() }
    }
  }
}

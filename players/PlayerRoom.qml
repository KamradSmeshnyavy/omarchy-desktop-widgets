import QtQuick
import ".."

// Плеер райса Cozy Room — старое радио на полке (свой): деревянный корпус (RoomWood) 460 × 210. Слева — решётка
// динамика из точек, которые «дышат» по уровням визуализатора; справа — шкала настройки цвета бумаги с делениями,
// название и исполнитель, красная стрелка идёт по треку (клик по шкале — перемотать), время; под ней — три ручки:
// назад · играть / пауза · вперёд (наведённая подсвечивается светом лампы). Обложка — маленькая пиксельная
// фотография на корпусе (уменьшена до 24 px, увеличена без сглаживания).
PlayerBase {
  id: p
  implicitWidth: 460; implicitHeight: 210
  RoomPal { id: rp }

  RoomWood {
    pal: rp
    anchors.fill: parent
    radius: 10
    pad: 12
    plank: 0

    // ── динамик ──
    Rectangle {
      id: grille
      width: 130; height: parent.height
      radius: 6
      color: rp.mix(rp.wood, rp.ink, 0.35)
      antialiasing: false
      Grid {
        anchors.centerIn: parent
        columns: 9; spacing: 6
        Repeater {
          model: 81
          Rectangle {
            required property int index
            readonly property real lv: p.level(index % 9, 9)
            width: 6; height: 6; radius: 3
            color: rp.mix(rp.ink, rp.lamp, Math.min(1, lv * 1.4 * (1 - Math.abs(Math.floor(index / 9) - 4) / 5)))
          }
        }
      }
    }

    // ── шкала ──
    Rectangle {
      id: dial
      x: grille.width + 14
      width: parent.width - x; height: 96
      color: rp.paper
      border.width: 2; border.color: rp.ink
      radius: 4
      antialiasing: false
      Repeater {   // деления
        model: 25
        Rectangle { required property int index; x: 8 + index * (dial.width - 16) / 24; y: dial.height - (index % 4 === 0 ? 16 : 10) - 4; width: 1; height: index % 4 === 0 ? 12 : 6; color: rp.alpha(rp.paperink, 0.5) }
      }
      Column {
        x: 10; y: 8; width: parent.width - 20; spacing: 2
        Text { width: parent.width; elide: Text.ElideRight; text: p.mpTitle || "тишина в эфире"; color: rp.paperink; font.family: rp.font; font.pixelSize: 19; font.bold: true }
        Text { width: parent.width; elide: Text.ElideRight; text: p.mpArtist || "покрутите ручку"; color: rp.alpha(rp.paperink, 0.65); font.family: rp.font; font.pixelSize: 15 }
      }
      Rectangle {   // стрелка
        x: 8 + (dial.width - 16) * p.frac - 1
        y: 50; width: 3; height: dial.height - 54
        color: rp.red; antialiasing: false
        Behavior on x { NumberAnimation { duration: 300 } }
      }
      Text { anchors.right: parent.right; anchors.rightMargin: 8; y: 52; text: p.fmt(p.mpPosition) + " / " + p.fmt(p.mpLength); color: rp.alpha(rp.paperink, 0.7); font.family: rp.mono; font.pixelSize: 13 }
      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: function(m) { p.seekAt(m.x - 8, dial.width - 16) } }
    }

    // ── ручки ──
    Row {
      x: dial.x + 4
      anchors.bottom: parent.bottom
      spacing: 18
      Repeater {
        model: [["◀◀", "назад"], [p.mpPlaying ? "▌▌" : "▶", p.mpPlaying ? "пауза" : "играть"], ["▶▶", "вперёд"]]
        Column {
          id: knob
          required property var modelData
          required property int index
          spacing: 2
          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 46; height: 46; radius: 23
            color: km.containsMouse ? rp.lamp : rp.dark
            border.width: 3; border.color: rp.ink
            Text { anchors.centerIn: parent; text: knob.modelData[0]; color: km.containsMouse ? rp.ink : rp.text; font.family: rp.font; font.pixelSize: 15; font.bold: true }
            MouseArea { id: km; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: p.act(knob.index) }
          }
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: knob.modelData[1]; color: rp.onWoodDim; font.family: rp.font; font.pixelSize: 12 }
        }
      }
    }
    // фотокарточка-обложка
    Rectangle {
      anchors.right: parent.right; anchors.bottom: parent.bottom
      width: 62; height: 62; rotation: 4
      color: rp.paper; border.width: 1; border.color: rp.ink; antialiasing: false
      Image {
        id: cover
        anchors.fill: parent; anchors.margins: 5
        source: p.mpCoverUrl
        sourceSize.width: 24; sourceSize.height: 24
        fillMode: Image.PreserveAspectCrop
        smooth: false; asynchronous: true
      }
      Image { anchors.centerIn: parent; visible: cover.status !== Image.Ready; source: rp.sprite("cat"); smooth: false; width: 32; height: 28 }
    }
  }
}

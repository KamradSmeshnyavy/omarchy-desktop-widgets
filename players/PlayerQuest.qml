import QtQuick
import ".."

// Плеер райса Quest — «бард» (свой): окно-диалог 460 × 230 с заголовком «БАРД ИГРАЕТ». Обложка — пиксель-арт:
// уменьшена до 32 px и увеличена без сглаживания, в рамке; рядом название (золото курсора), исполнитель, шкала клетками
// (клик — перемотать) со временем; над ней — пиксельные столбики визуализатора цветом MP. Внизу три команды, как в
// меню игры: ◀◀ · ИГРАТЬ / ПАУЗА · ▶▶ — рука-курсор у наведённой.
PlayerBase {
  id: p
  implicitWidth: 460; implicitHeight: 230
  QuestPal { id: qp }
  property int hoverCmd: 1

  QuestWin {
    pal: qp
    anchors.fill: parent
    pad: 6

    Text { x: 2; y: 0; text: p.mpPlaying ? "♪ БАРД ИГРАЕТ" : "♪ БАРД ОТДЫХАЕТ"; color: qp.hi; font.family: qp.font(8); font.pixelSize: qp.size(8) }

    // обложка: 32 px → 104 px без сглаживания
    Rectangle {
      id: art
      x: 0; y: 22; width: 108; height: 108
      color: qp.ink; border.width: 2; border.color: qp.frame2; antialiasing: false
      Image {
        id: cover
        anchors.fill: parent; anchors.margins: 2
        source: p.mpCoverUrl
        sourceSize.width: 32; sourceSize.height: 32
        fillMode: Image.PreserveAspectCrop
        smooth: false; asynchronous: true
      }
      Image { anchors.centerIn: parent; visible: cover.status !== Image.Ready; source: qp.sprite("heart"); smooth: false; width: 42; height: 36 }
    }

    Column {
      x: art.width + 16; y: 22
      width: parent.width - x
      spacing: 6
      Text { width: parent.width; elide: Text.ElideRight; text: p.mpTitle || "тишина"; color: qp.hi; font.family: qp.body; font.pixelSize: 20 }
      Text { width: parent.width; elide: Text.ElideRight; text: p.mpArtist || "бард настраивает лютню"; color: qp.dim; font.family: qp.body; font.pixelSize: 16 }
      // визуализатор: 20 столбиков клетками
      Item {
        id: viz
        width: parent.width; height: 34
        Repeater {
          model: 20
          Column {
            required property int index
            readonly property int cells: Math.max(1, Math.round(p.level(index, 20) * 6))
            x: index * (viz.width / 20)
            anchors.bottom: parent.bottom
            spacing: 1
            Repeater {
              model: parent.cells
              Rectangle { width: viz.width / 20 - 3; height: 4; color: qp.mp; antialiasing: false }
            }
          }
        }
      }
      Row {
        spacing: 8
        Rectangle {
          id: track
          width: viz.width - time.implicitWidth - 8; height: 12
          color: qp.ink; border.width: 1; border.color: qp.frame2; antialiasing: false
          anchors.verticalCenter: parent.verticalCenter
          Row {
            x: 2; y: 2; spacing: 1
            Repeater {
              model: 24
              Rectangle { required property int index; width: (track.width - 4) / 24 - 1; height: 8; antialiasing: false; color: index < Math.round(p.frac * 24) ? qp.hp : "transparent" }
            }
          }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: function(m) { p.seekAt(m.x, width) } }
        }
        Text { id: time; text: p.fmt(p.mpPosition) + "/" + p.fmt(p.mpLength); color: qp.text; font.family: qp.mono; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
      }
    }

    // команды
    Row {
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 34
      Repeater {
        model: ["◀◀", p.mpPlaying ? "ПАУЗА" : "ИГРАТЬ", "▶▶"]
        Item {
          id: cmd
          required property string modelData
          required property int index
          width: ct.implicitWidth; height: 26
          Text { id: ct; anchors.verticalCenter: parent.verticalCenter; text: cmd.modelData; color: p.hoverCmd === cmd.index ? qp.hi : qp.text; font.family: qp.font(8); font.pixelSize: qp.size(8) }
          Image { visible: p.hoverCmd === cmd.index; source: qp.sprite("hand"); smooth: false; width: 16; height: 11; x: -22; anchors.verticalCenter: parent.verticalCenter }
          MouseArea { anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: p.hoverCmd = cmd.index; onClicked: p.act(cmd.index) }
        }
      }
    }
  }
}

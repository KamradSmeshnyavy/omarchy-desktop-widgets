import QtQuick
import QtQuick.Shapes
import ".."

// Плеер Space (по мотивам стиля Space из elifouts/Dotfiles, GPL-3.0 — его common/MediaCard.qml и музыкальная карточка
// с его скриншотов: NOW PLAYING, перемотка штрихами, симметричный визуализатор): плашка 420 × 230 со срезанным углом
// 14 px, рамка акцентом 35 %, черта 2 px акцентом слева, уголки 7 px. Шапка «♪ NOW PLAYING» с чертой; обложка 64 px,
// трек, исполнитель; симметричные столбики визуализатора акцентом; ⏮ ⏯ ⏭ (пауза — в рамке); «02:56 · 72% · -01:08» и
// перемотка — 64 штриха с бегунком (клик — перемотать).
PlayerBase {
  id: p
  implicitWidth: 420; implicitHeight: 230
  readonly property string mono: font("JetBrainsMono Nerd Font", "monospace")

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeWidth: 1
      strokeColor: p.alpha(p.accent, 0.35)
      fillColor: p.alpha(p.bg, 0.82)
      startX: 14; startY: 0
      PathLine { x: p.width; y: 0 }
      PathLine { x: p.width; y: p.height }
      PathLine { x: 0; y: p.height }
      PathLine { x: 0; y: 14 }
      PathLine { x: 14; y: 0 }
    }
  }
  Rectangle { x: 0; y: 14; width: 2; height: p.height - 14; color: p.accent }
  Repeater {
    model: [1, 2, 3]
    Item {
      required property int modelData
      x: modelData % 2 ? p.width - 7 : 0
      y: modelData > 1 ? p.height - 7 : 0
      width: 7; height: 7
      Rectangle { width: 7; height: 1; y: parent.modelData > 1 ? 6 : 0; color: p.accent }
      Rectangle { width: 1; height: 7; x: parent.modelData % 2 ? 6 : 0; color: p.accent }
    }
  }

  // шапка
  Item {
    x: 16; y: 10; width: p.width - 32; height: 24
    Text { id: hg; text: "󰎈"; font.family: p.mono; font.pixelSize: 14; color: p.accent; anchors.verticalCenter: parent.verticalCenter }
    SpaceDecode { x: hg.width + 8; height: parent.height; family: p.mono; text: "now playing"; color: p.fg }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: p.alpha(p.accent, 0.25) }
  }

  // обложка и трек
  Rectangle {
    id: art
    x: 16; y: 44; width: 64; height: 64
    color: p.alpha(p.fg, 0.08)
    border.width: 1; border.color: p.alpha(p.accent, 0.35)
    Image { anchors.fill: parent; anchors.margins: 1; source: p.mpCoverUrl; fillMode: Image.PreserveAspectCrop; asynchronous: true }
  }
  Column {
    x: art.x + art.width + 12; y: 48
    width: p.width - x - 16
    spacing: 4
    Text { width: parent.width; elide: Text.ElideRight; text: p.mpTitle || "silence"; color: p.fg; font.family: p.mono; font.pixelSize: 15 }
    Text { width: parent.width; elide: Text.ElideRight; text: p.mpArtist || "nothing playing"; color: p.alpha(p.fg, 0.6); font.family: p.mono; font.pixelSize: 12 }
    // визуализатор: симметричные столбики, как у него на столе
    Row {
      height: 26
      spacing: 2
      Repeater {
        model: 44
        Rectangle {
          required property int index
          readonly property real lv: p.level(Math.abs(index - 21.5) | 0, 22)
          width: 3
          height: 2 + 24 * lv
          anchors.verticalCenter: parent ? parent.verticalCenter : undefined
          color: p.accent
          opacity: 0.35 + 0.65 * lv
        }
      }
    }
  }

  // кнопки
  Row {
    anchors.horizontalCenter: parent.horizontalCenter
    y: 122
    spacing: 18
    Repeater {
      model: [["󰒮", 0], [p.mpPlaying ? "󰏤" : "󰐊", 1], ["󰒭", 2]]
      Rectangle {
        required property var modelData
        readonly property bool big: modelData[1] === 1
        width: big ? 40 : 30; height: big ? 40 : 30
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: big ? p.alpha(p.accent, h.hovered ? 0.3 : 0.15) : (h.hovered ? p.alpha(p.accent, 0.12) : "transparent")
        border.width: big ? 1 : 0
        border.color: p.alpha(p.accent, 0.5)
        Text { anchors.centerIn: parent; text: modelData[0]; color: p.fg; font.family: p.mono; font.pixelSize: big ? 16 : 13 }
        HoverHandler { id: h; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: p.act(modelData[1]) }
      }
    }
  }

  // время и перемотка штрихами
  Item {
    x: 16; y: 176; width: p.width - 32; height: 14
    Text { text: p.fmt(p.mpPosition); color: p.alpha(p.fg, 0.55); font.family: p.mono; font.pixelSize: 10; font.letterSpacing: 1.2 }
    Text { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(p.frac * 100) + "%"; color: p.alpha(p.fg, 0.4); font.family: p.mono; font.pixelSize: 10; font.letterSpacing: 1.2 }
    Text { anchors.right: parent.right; text: "-" + p.fmt(p.mpLength - p.mpPosition); color: p.alpha(p.fg, 0.55); font.family: p.mono; font.pixelSize: 10; font.letterSpacing: 1.2 }
  }
  Item {
    id: seek
    x: 16; y: 196; width: p.width - 32; height: 18
    Row {
      anchors.bottom: parent.bottom
      spacing: (seek.width - 64) / 63
      Repeater {
        model: 64
        Rectangle {
          required property int index
          width: 1; height: index % 8 === 0 ? 9 : 5
          anchors.bottom: parent ? parent.bottom : undefined
          color: index / 63 <= p.frac ? p.accent : p.alpha(p.fg, 0.25)
        }
      }
    }
    Rectangle { x: seek.width * p.frac - 1; width: 2; height: seek.height; color: p.fg }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: function(e) { p.seekAt(e.x, width) } }
  }
}

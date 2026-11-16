import QtQuick
import QtQuick.Effects

// Плеер surface: карточка 380 × 210 со скруглением 16 на размытой обложке под тёмной вуалью (как его плеер в Hub),
// обложка 96 со скруглением 12, название Manrope и исполнитель курсивом, длинная волнистая линия прогресса акцентом
// (проигранное — волной, остальное — ровно), три кнопки в пилюле.
PlayerBase {
  id: p
  implicitWidth: 380; implicitHeight: 210
  readonly property string sans: font("Manrope", "sans-serif")
  Rectangle {
    id: cardR
    anchors.fill: parent; radius: 16; color: p.bg; clip: true
    Image { id: blurSrc; anchors.fill: parent; source: p.mpCoverUrl; fillMode: Image.PreserveAspectCrop; visible: false }
    MultiEffect { anchors.fill: parent; source: blurSrc; visible: blurSrc.status === Image.Ready; blurEnabled: true; blur: 1; blurMax: 64; opacity: 0.55 }
    Rectangle { anchors.fill: parent; color: p.alpha(p.bg, 0.55) }
    Rectangle {
      x: 18; y: 18; width: 96; height: 96; radius: 12; color: p.alpha(p.fg, 0.1); clip: true
      Image { id: art; anchors.fill: parent; source: p.mpCoverUrl; fillMode: Image.PreserveAspectCrop; visible: false; layer.enabled: true }
      Rectangle { id: msk; anchors.fill: parent; radius: 12; visible: false; layer.enabled: true }
      MultiEffect { anchors.fill: parent; source: art; visible: art.status === Image.Ready; maskEnabled: true; maskSource: msk; maskThresholdMin: 0.5 }
    }
    Column {
      x: 130; y: 26; width: 232; spacing: 6
      Text { width: parent.width; elide: Text.ElideRight; text: p.mpTitle; color: p.fg; font.family: p.sans; font.pixelSize: 16; font.weight: 800 }
      Text { width: parent.width; elide: Text.ElideRight; text: p.mpArtist; color: p.alpha(p.fg, 0.7); font.family: p.sans; font.pixelSize: 12; font.italic: true }
    }
    Canvas {
      id: wave
      x: 18; y: 132; width: 344; height: 20
      property real ph: 0
      NumberAnimation on ph { from: 0; to: Math.PI * 2; duration: 1800; loops: Animation.Infinite; running: p.mpPlaying && p.shown }
      onPhChanged: requestPaint()
      onPaint: {
        var c = getContext("2d"); c.reset(); var w = width, mid = height / 2, cut = w * p.frac
        c.lineWidth = 3; c.lineCap = "round"
        c.strokeStyle = p.accent; c.beginPath()
        for (var x = 0; x <= cut; x += 2) { var y = mid + Math.sin(x / 7 + ph) * 4; if (x === 0) c.moveTo(x, y); else c.lineTo(x, y) }
        c.stroke()
        c.strokeStyle = Qt.rgba(p.fg.r, p.fg.g, p.fg.b, 0.25); c.beginPath(); c.moveTo(cut + 4, mid); c.lineTo(w, mid); c.stroke()
      }
      MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: function(e) { p.seekAt(e.x, width) } }
    }
    Text { x: 18; y: 160; text: p.fmt(p.mpPosition); color: p.alpha(p.fg, 0.6); font.family: p.sans; font.pixelSize: 10 }
    Text { anchors.right: parent.right; anchors.rightMargin: 18; y: 160; text: p.fmt(p.mpLength); color: p.alpha(p.fg, 0.6); font.family: p.sans; font.pixelSize: 10 }
    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter; y: 160; width: 132; height: 36; radius: 18; color: p.alpha(p.fg, 0.1)
      Row {
        anchors.centerIn: parent; spacing: 16
        Repeater {
          model: [["\u{F04AE}", 0], [p.mpPlaying ? "\u{F03E4}" : "\u{F040A}", 1], ["\u{F04AD}", 2]]
          Text {
            required property var modelData
            text: modelData[0]; color: h.hovered || modelData[1] === 1 ? p.accent : p.fg; font.pixelSize: modelData[1] === 1 ? 22 : 17
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            HoverHandler { id: h; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: p.act(modelData[1]) }
          }
        }
      }
    }
  }
}

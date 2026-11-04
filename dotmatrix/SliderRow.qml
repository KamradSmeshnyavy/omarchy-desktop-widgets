import QtQuick
import QtQuick.Layouts
import "." as N

// Glyph (click — mute) + 24-segment LED slider + percent.
RowLayout {
  id: srow

  property string glyph: ""
  property real value: 0
  property bool muted: false
  signal moved(real value)
  signal glyphClicked()

  spacing: 12

  Ico {
    Layout.preferredWidth: 22
    glyph: srow.glyph
    color: srow.muted ? N.Palette.danger : N.Palette.dim

    MouseArea {
      anchors.fill: parent
      anchors.margins: -6
      cursorShape: Qt.PointingHandCursor
      onClicked: srow.glyphClicked()
    }
  }

  SegSlider {
    Layout.fillWidth: true
    value: srow.value
    muted: srow.muted
    onMoved: function(v) { srow.moved(v) }
  }

  Label {
    Layout.preferredWidth: 30
    horizontalAlignment: Text.AlignRight
    text: String(Math.round(srow.value * 100))
  }
}

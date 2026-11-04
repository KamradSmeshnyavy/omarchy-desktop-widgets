import QtQuick
import QtQuick.Layouts
import "." as N

// List row of the Nihil settings drawer: glyph, title (+ optional subtitle), metadata
// label and an optional round action button on the right (forget, set default, …).
Rectangle {
  id: lrow

  property string glyph: ""
  property string title: ""
  property string subtitle: ""
  property string detail: ""
  property string action: ""          // glyph of the action button; empty — no button
  property bool actionDanger: false
  property bool current: false
  property bool busy: false
  signal clicked()
  signal actionClicked()

  Layout.fillWidth: true
  implicitHeight: subtitle !== "" ? 46 : 38
  radius: N.Finish.nihil ? 12 : N.Finish.radius
  color: hover.hovered ? N.Palette.surfaceHi : "transparent"

  // HoverHandler, not the MouseArea: the action button on top must not drop the row hover.
  HoverHandler { id: hover }

  MouseArea {
    id: rowArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: lrow.clicked()
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 12
    anchors.rightMargin: 8
    spacing: 10

    Ico { glyph: lrow.glyph; color: lrow.current ? N.Palette.fg : N.Palette.muted }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 1

      Txt {
        Layout.fillWidth: true
        text: lrow.title
        color: lrow.current ? N.Palette.fg : N.Palette.dim
        font.weight: lrow.current ? Font.Medium : Font.Normal
      }

      Label {
        Layout.fillWidth: true
        visible: lrow.subtitle !== ""
        text: lrow.subtitle
        font.pixelSize: 9
      }
    }

    Label { text: lrow.busy ? "···" : lrow.detail }

    CircleButton {
      visible: lrow.action !== "" && (hover.hovered || lrow.current)
      glyph: lrow.action
      size: 26
      danger: lrow.actionDanger
      onClicked: lrow.actionClicked()
    }
  }
}

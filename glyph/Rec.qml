import QtQuick

// Из glyph-rice (quick/Rec.qml, GPL-3.0). Настройки записи под плитками (правый клик по record): область, звук, камера.
// Опции — то, что умеет omarchy-capture-screenrecording (gpu-screen-recorder / wf-recorder); живут в quick.json.
Rectangle {
  id: root
  signal touched // любой клик внутри — панель приколота
  signal start
  signal changed(string key, var value)

  property var st: ({})       // { recArea, recAudio, recWebcam }
  property bool recording: false
  property string dir: "~/Videos"

  height: list.height + 32
  radius: 30
  color: GTheme.s2

  Column {
    id: list
    x: 16
    y: 16
    width: parent.width - 32
    spacing: 8

    Lb { x: 4; text: "recording · " + root.dir }

    Choice { label: "area"; opts: ["region", "screen"]; cur: root.st.recArea === 1 ? 1 : 0; onPicked: function(i) { root.changed("recArea", i) } }
    Choice { label: "audio"; opts: ["off", "sys", "mic", "both"]; cur: Math.max(0, Math.min(3, Number(root.st.recAudio) || 0)); onPicked: function(i) { root.changed("recAudio", i) } }
    Choice { label: "webcam"; opts: ["off", "on"]; cur: root.st.recWebcam === true ? 1 : 0; onPicked: function(i) { root.changed("recWebcam", i === 1) } }

    // старт/стоп; идёт запись — красная точка, единственное красное на панели
    Rectangle {
      width: list.width
      height: 54
      radius: 27
      color: GTheme.fg
      Row {
        anchors.centerIn: parent
        spacing: 10
        Rectangle { visible: root.recording; anchors.verticalCenter: parent.verticalCenter; width: 10; height: 10; radius: 5; color: GTheme.accent }
        Lb { anchors.verticalCenter: parent.verticalCenter; text: root.recording ? "stop recording" : "start recording"; color: GTheme.ink }
      }
      TapHandler { onTapped: root.start() }
      HoverHandler { cursorShape: Qt.PointingHandCursor }
    }
  }

  // ряд выбора: метка слева, белая заливка переезжает к выбранной клетке
  component Choice: Item {
    id: ch
    property string label
    property var opts: []
    property int cur
    signal picked(int i)
    width: list.width
    height: 44
    Lb { x: 4; anchors.verticalCenter: parent.verticalCenter; text: ch.label; px: 10 }
    Rectangle {
      id: track
      x: 96
      width: parent.width - x
      height: parent.height
      radius: height / 2
      color: GTheme.s1
      readonly property real cell: (width - 8) / ch.opts.length
      Rectangle {
        x: 4 + track.cell * ch.cur
        y: 4
        width: track.cell
        height: parent.height - 8
        radius: height / 2
        color: GTheme.fg
        Behavior on x { NumberAnimation { duration: GTheme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: GTheme.glide } }
      }
      Repeater {
        model: ch.opts
        Item {
          id: cell
          required property int index
          required property var modelData
          x: 4 + track.cell * index
          width: track.cell
          height: track.height
          Lb { anchors.centerIn: parent; px: 10; text: cell.modelData; color: ch.cur === cell.index ? GTheme.ink : GTheme.grey }
          TapHandler { onTapped: { root.touched(); ch.picked(cell.index) } }
          HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
      }
    }
  }
}

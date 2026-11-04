import QtQuick
import Quickshell
import Quickshell.Io
import "dotmatrix" as DotMatrix

// Todo / заметки на рабочем столе: ~/.config/omarchy/widgets-todo.json — [{"text": "…", "done": false}, …].
// Клик по квадратику — сделано / не сделано, правый клик по строке — удалить, «+» — добавить (окно ввода
// zenity: слой рабочего стола не берёт клавиатуру). Вид — по стилю (шрифт, форма отметки — N.Finish).
Item {
  id: todo

  required property var host
  readonly property bool dotmatrix: host.dotmatrixWidgets
  readonly property string face: dotmatrix ? DotMatrix.Palette.fontSans : host.fontFamily
  readonly property string titleFace: dotmatrix ? DotMatrix.Palette.fontTitle : host.fontFamily
  readonly property int maxItems: Math.max(1, host.num("todoMax"))
  readonly property string path: Quickshell.env("HOME") + "/.config/omarchy/widgets-todo.json"

  property var items: []

  width: 300
  height: col.implicitHeight

  function save(list) {
    todo.items = list
    store.setText(JSON.stringify(list, null, 2) + "\n")
  }
  function toggle(i) {
    var l = todo.items.slice()
    l[i] = { text: l[i].text, done: !l[i].done }
    todo.save(l)
  }
  function remove(i) {
    var l = todo.items.slice()
    l.splice(i, 1)
    todo.save(l)
  }

  FileView {
    id: store
    path: todo.path
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var v = JSON.parse(text() || "[]")
        todo.items = Array.isArray(v) ? v.filter(function(x) { return x && String(x.text || "") !== "" }) : []
      } catch (e) { todo.items = [] }
    }
    onLoadFailed: todo.items = []
  }

  // «+»: строка из окна ввода дописывается в конец (пустая — ничего).
  Process {
    id: asker
    command: ["zenity", "--entry", "--title=Todo", "--text=New item:"]
    stdout: StdioCollector {
      onStreamFinished: {
        var t = String(text || "").trim()
        if (t !== "") todo.save(todo.items.concat([{ text: t, done: false }]))
      }
    }
  }

  Column {
    id: col
    width: parent.width
    spacing: 8

    Row {
      width: parent.width
      Text {
        width: parent.width - plus.width
        text: todo.dotmatrix ? "TODO" : "Todo"
        color: todo.host.foreground
        font.family: todo.titleFace
        font.pixelSize: todo.dotmatrix ? 16 : 26
        font.weight: DotMatrix.Palette.titleWeight(Font.DemiBold)
        font.letterSpacing: todo.dotmatrix ? 2 : 0
      }
      Text {
        id: plus
        text: "+"
        color: plusArea.containsMouse ? todo.host.accent : todo.host.muted
        font.family: todo.face
        font.pixelSize: 26
        MouseArea {
          id: plusArea
          anchors.fill: parent
          anchors.margins: -8
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: if (!asker.running) asker.running = true
        }
      }
    }

    Text {
      visible: todo.items.length === 0
      text: "+  add a task"
      color: todo.host.muted
      font.family: todo.face
      font.pixelSize: 15
    }

    Repeater {
      model: todo.items.slice(0, todo.maxItems)
      Item {
        required property var modelData
        required property int index
        width: col.width
        height: Math.max(22, label.implicitHeight)

        Rectangle {
          id: box
          anchors.verticalCenter: parent.verticalCenter
          width: 16
          height: 16
          radius: DotMatrix.Finish.round(16) * (todo.dotmatrix ? 1 : 0.5)
          color: modelData.done ? todo.host.accent : "transparent"
          border.width: Math.max(1.5, DotMatrix.Finish.borderWidth)
          border.color: modelData.done ? todo.host.accent : todo.host.muted
          Text {
            anchors.centerIn: parent
            visible: modelData.done
            text: "✓"
            font.pixelSize: 12
            font.bold: true
            color: todo.host.background
          }
        }
        Text {
          id: label
          anchors.left: box.right
          anchors.leftMargin: 10
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: modelData.text
          wrapMode: Text.Wrap
          maximumLineCount: 2
          elide: Text.ElideRight
          color: modelData.done ? todo.host.muted : todo.host.foreground
          font.family: todo.face
          font.pixelSize: 15
          font.strikeout: modelData.done
        }
        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          cursorShape: Qt.PointingHandCursor
          onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) todo.remove(index)
            else todo.toggle(index)
          }
        }
      }
    }

    Text {
      visible: todo.items.length > todo.maxItems
      text: "+" + (todo.items.length - todo.maxItems) + " …"
      color: todo.host.muted
      font.family: todo.face
      font.pixelSize: 13
    }
  }
}

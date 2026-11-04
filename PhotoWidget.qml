import QtQuick
import Quickshell
import Quickshell.Io
import "nihil" as Nihil

// Фото-рамка: картинка из папки photoDir (widgets.json; ~ раскрывается) со сменой раз в photoInterval
// минут и по клику; без папки — текущие обои. Под снимком — подпись (имя файла). Рамку рисует
// подложка стиля (WidgetCard): у Бумаги — полароид со скотчем, у Ретро — кант, у Неона — свечение.
Item {
  id: photo

  required property var host
  readonly property bool nihil: host.nihilWidgets
  readonly property string face: nihil ? Nihil.Palette.fontMono : host.fontFamily
  readonly property string dir: String(host.value("photoDir") || "").replace(/^~\//, Quickshell.env("HOME") + "/")
  readonly property int minutes: Math.max(1, host.num("photoInterval"))
  readonly property string wallpaper: Quickshell.env("HOME") + "/.local/state/omarchy/current/background"

  property var files: []
  property int index: 0
  readonly property string source: photo.dir !== "" && photo.files.length > 0 ? photo.files[photo.index % photo.files.length] : photo.wallpaper
  readonly property string caption: photo.dir === "" ? "" : String(photo.source).split("/").pop().replace(/\.[^.]+$/, "")

  width: 260
  height: frame.height + (cap.visible ? cap.height + 8 : 0)

  function next() {
    if (photo.files.length > 1) photo.index = (photo.index + 1 + Math.floor(Math.random() * (photo.files.length - 1))) % photo.files.length
  }

  // Список картинок папки (до двух уровней), перечитывается при смене папки и раз в час.
  Process {
    id: lister
    command: ["find", "-L", photo.dir, "-maxdepth", "2", "-type", "f", "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg",
      "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")"]
    stdout: StdioCollector {
      onStreamFinished: {
        photo.files = String(text || "").split("\n").filter(function(l) { return l !== "" }).sort()
        photo.index = photo.files.length > 0 ? Math.floor(Math.random() * photo.files.length) : 0
      }
    }
  }
  onDirChanged: if (photo.dir !== "") lister.running = true
  Component.onCompleted: if (photo.dir !== "") lister.running = true
  Timer { interval: 3600000; running: photo.dir !== ""; repeat: true; onTriggered: lister.running = true }
  Timer { interval: photo.minutes * 60000; running: photo.visible; repeat: true; onTriggered: photo.next() }

  Rectangle {
    id: frame
    width: parent.width
    height: Math.round(width * 0.72)
    color: Qt.rgba(photo.host.foreground.r, photo.host.foreground.g, photo.host.foreground.b, 0.06)
    radius: photo.nihil ? 12 : Math.min(Nihil.Finish.radius, 10)
    clip: true
    Image {
      anchors.fill: parent
      source: photo.source !== "" ? "file://" + photo.source : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      sourceSize.width: 520
      sourceSize.height: 380
    }
  }
  Text {
    id: cap
    visible: photo.caption !== ""
    anchors.top: frame.bottom
    anchors.topMargin: 8
    width: parent.width
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
    text: photo.nihil ? photo.caption.toUpperCase() : photo.caption
    color: photo.host.muted
    font.family: photo.face
    font.pixelSize: photo.nihil ? 10 : 16
    font.letterSpacing: photo.nihil ? 1.5 : 0
  }
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: photo.next()
  }
}

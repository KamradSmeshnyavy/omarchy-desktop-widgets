import QtQuick
import Quickshell
import Quickshell.Io
import "dotmatrix" as DotMatrix

// Цитата дня: встроенные пословицы и изречения давно умерших авторов + свои строки из
// ~/.config/omarchy/widgets-quotes.txt («текст — Автор», по одной на строку; # — комментарий; автор — после
// последнего « — », с заглавной буквы).
// Цитата меняется раз в сутки, клик — следующая.
Item {
  id: quote

  required property var host
  readonly property bool dotmatrix: host.dotmatrixWidgets
  readonly property string face: dotmatrix ? DotMatrix.Palette.fontSans : host.fontFamily

  readonly property var builtIn: [
    "Дорогу осилит идущий.",
    "Тише едешь — дальше будешь.",
    "Повторение — мать учения.",
    "Глаза боятся, а руки делают.",
    "Без труда не выловишь и рыбку из пруда.",
    "Делу время — потехе час.",
    "Утро вечера мудренее.",
    "Учиться никогда не поздно.",
    "Well begun is half done.|Aristotle",
    "The journey of a thousand miles begins with a single step.|Lao Tzu",
    "Knowledge is power.|Francis Bacon",
    "Simplicity is the ultimate sophistication.|Leonardo da Vinci",
    "Ars longa, vita brevis.|Hippocrates",
    "Festina lente.|Augustus",
    "Little by little, one travels far.|J. R. R. Tolkien",
    "It does not matter how slowly you go as long as you do not stop.|Confucius",
    "Brevity is the soul of wit.|William Shakespeare",
    "Nothing is impossible to a willing heart.|John Heywood",
    "Краткость — сестра таланта.|А. П. Чехов",
    "Терпение и труд всё перетрут.",
    "Век живи — век учись.",
    "Better late than never.",
    "A small leak will sink a great ship.|Benjamin Franklin",
    "Well done is better than well said.|Benjamin Franklin"
  ]
  property var own: []
  readonly property var all: own.length > 0 ? own.concat(builtIn) : builtIn
  property int offset: 0
  function dayOfYear() { var d = new Date(); return Math.floor((d - new Date(d.getFullYear(), 0, 0)) / 86400000) }
  property int day: dayOfYear()
  readonly property string current: all.length > 0 ? all[(day + offset) % all.length] : ""
  // Встроенные: «текст|автор»; свои строки: автор — после последнего « — » (тире внутри пословицы не режет).
  readonly property int cut: current.indexOf("|") >= 0 ? current.indexOf("|") : current.lastIndexOf(" — ")
  readonly property int cutLen: current.indexOf("|") >= 0 ? 1 : 3
  readonly property bool hasAuthor: cut > 0 && (current.indexOf("|") >= 0 || /^[A-ZА-ЯЁ]/.test(current.slice(cut + 3)))
  readonly property string body: hasAuthor ? current.slice(0, cut) : current
  readonly property string author: hasAuthor ? current.slice(cut + cutLen) : ""

  width: 320
  height: col.implicitHeight

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/widgets-quotes.txt"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: quote.own = String(text() || "").split("\n").map(function(l) { return l.trim() })
      .filter(function(l) { return l !== "" && l.charAt(0) !== "#" })
    onLoadFailed: quote.own = []
  }
  // Новый день — новая цитата (без перезапуска).
  Timer { interval: 600000; running: true; repeat: true; onTriggered: quote.day = quote.dayOfYear() }

  Column {
    id: col
    width: parent.width
    spacing: 8
    Text {
      text: quote.dotmatrix ? "QUOTE" : "“"
      color: quote.host.accent
      font.family: quote.dotmatrix ? DotMatrix.Palette.fontMono : quote.face
      font.pixelSize: quote.dotmatrix ? 11 : 44
      font.letterSpacing: quote.dotmatrix ? 2 : 0
      height: quote.dotmatrix ? implicitHeight : 26
    }
    Text {
      width: parent.width
      text: quote.body
      wrapMode: Text.Wrap
      color: quote.host.foreground
      font.family: quote.face
      font.pixelSize: 18
      lineHeight: 1.15
    }
    Text {
      visible: quote.author !== ""
      width: parent.width
      horizontalAlignment: Text.AlignRight
      text: "— " + quote.author
      color: quote.host.muted
      font.family: quote.face
      font.pixelSize: 13
      font.italic: !quote.dotmatrix
    }
  }
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: quote.offset += 1
  }
}

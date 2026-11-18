import QtQuick
import Quickshell
import qs.Commons as Commons

// Терминал на обоях (по мотивам виджета term из github.com/elifouts/Dotfiles, GPL-3.0 — его WidgetShared.qml + desk.sh):
// виджет только сообщает своё место, а настоящий bash держит omarchy-desk-term — `kitten panel` kitty на фоновом слое
// под этим слоем виджетов, прозрачный, фокус по клику (клики сюда не попадают — виджета нет в mask слоя). Размер — треть
// экрана × termScale. Терминал перезапускается, только когда меняется место или размер; при смене темы меняются
// только шрифт и фон (через сокет kitty). В режиме правки — пунктирная рамка TERMINAL, её можно тащить.
Item {
  id: term
  required property var host
  property string output: ""
  property point origin: Qt.point(0, 0)   // где окно слоя виджетов на экране (под баром — сдвиг)
  readonly property bool editing: host.editMode
  readonly property string key: "term-" + output

  width: Screen.width > 0 ? Math.round(Screen.width / 3) : 480
  height: Screen.height > 0 ? Math.round(Screen.height / 3) : 300

  readonly property color bg: Commons.Color.background
  readonly property string rice: String(host.rice || "")
  readonly property string font: rice === "crt" && Qt.fontFamilies().indexOf("Terminess Nerd Font Mono") !== -1 ? "Terminess Nerd Font Mono" : ""
  function hex(c) { return "#" + [c.r, c.g, c.b].map(function(v) { return ("0" + Math.round(v * 255).toString(16)).slice(-2) }).join("") }

  // место на экране, с учётом масштаба виджета (scale — вокруг центра)
  function spot() {
    if (!visible || output === "") return ""
    var a = mapToItem(null, 0, 0), b = mapToItem(null, width, height)
    var x = Math.round(origin.x + Math.min(a.x, b.x)), y = Math.round(origin.y + Math.min(a.y, b.y))
    var w = Math.round(Math.abs(b.x - a.x)), h = Math.round(Math.abs(b.y - a.y))
    return [output, x, y, w, h, 2, 11, hex(bg), 0].concat(font ? [font] : []).join(" ")
  }
  property string sent: ""
  function report() {
    if (editing) return  // в правке терминал не трогаем — место сообщим, когда отпустят
    var s = spot()
    if (s === sent) return
    sent = s
    Quickshell.execDetached(s === "" ? ["omarchy-desk-term", "hide", key] : ["omarchy-desk-term", "show", key].concat(s.split(" ")))
  }
  Timer { id: place; interval: 250; onTriggered: term.report() }
  onXChanged: place.restart()
  onYChanged: place.restart()
  onScaleChanged: place.restart()
  onVisibleChanged: place.restart()
  onEditingChanged: if (!editing) place.restart()
  onOriginChanged: place.restart()
  onBgChanged: place.restart()
  onFontChanged: place.restart()
  Component.onCompleted: place.restart()
  Component.onDestruction: if (sent !== "") Quickshell.execDetached(["omarchy-desk-term", "hide", key])

  // режим правки: где будет терминал
  Rectangle {
    visible: term.editing
    anchors.fill: parent
    color: Qt.rgba(term.bg.r, term.bg.g, term.bg.b, 0.35)
    border.width: 1
    border.color: Commons.Color.accent
    Text {
      anchors.centerIn: parent
      text: "TERMINAL"
      color: Commons.Color.accent
      font.family: term.font || "monospace"
      font.pixelSize: 14
      font.letterSpacing: 2
    }
  }
}

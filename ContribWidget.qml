import Quickshell
import QtQuick
import "dotmatrix" as DotMatrix

// График вкладов GitHub (по мотивам rumda): последние contribWeeks недель квадратиками 7 × N, цвет — уровень
// активности 0–4 (акцент с разной прозрачностью). Данные — публичный github-contributions-api.jogruber.de, запрос
// уходит только если задан githubUser; обновление раз в 3 часа, пока виджет виден. Клик — профиль на GitHub.
Item {
  id: w

  required property var host          // Widgets.qml

  readonly property string user: String(host.value("githubUser") || "").trim().replace(/^@/, "")
  readonly property int weeks: Math.max(8, Math.min(53, Math.round(host.num("contribWeeks"))))
  readonly property bool dot: host.dotmatrixWidgets
  readonly property color fg: dot ? DotMatrix.Palette.fg : host.foreground
  readonly property color accent: dot ? DotMatrix.Palette.fg : host.accent
  readonly property int cell: 9
  readonly property int gap: 3

  property var days: []               // [{ date, count, level }] по возрастанию даты
  property int total: 0
  property string error: ""
  property double fetchedAt: 0
  property string fetchedFor: ""

  implicitWidth: Math.max(220, weeks * (cell + gap) - gap)
  implicitHeight: header.height + 10 + 7 * (cell + gap) - gap
  width: implicitWidth
  height: implicitHeight

  function refresh() {
    if (user === "") { days = []; error = ""; return }
    if (user === fetchedFor && Date.now() - fetchedAt < 3 * 3600 * 1000 && days.length > 0) return
    fetchedFor = user
    fetchedAt = Date.now()
    var xhr = new XMLHttpRequest()
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      try {
        var d = JSON.parse(xhr.responseText)
        if (xhr.status !== 200 || !d.contributions) throw new Error(d.error || ("HTTP " + xhr.status))
        w.days = d.contributions
        var t = 0
        for (var k in d.total) t += Number(d.total[k]) || 0
        w.total = t
        w.error = ""
      } catch (e) {
        w.error = host.tr("GitHub: ", "GitHub: ") + String(e.message || e)
        w.fetchedAt = 0
      }
    }
    xhr.open("GET", "https://github-contributions-api.jogruber.de/v4/" + encodeURIComponent(user) + "?y=last")
    xhr.send()
  }
  onUserChanged: refresh()
  onVisibleChanged: if (visible) refresh()
  Component.onCompleted: refresh()
  Timer { interval: 30 * 60 * 1000; repeat: true; running: w.visible && w.user !== ""; onTriggered: w.refresh() }

  // Последние weeks недель, выровненные по неделям (столбец — неделя, строка — день, пн сверху).
  readonly property var grid: {
    var list = days
    if (!list.length) return []
    var last = list.length - 1
    var lastDow = (new Date(list[last].date).getDay() + 6) % 7
    var start = last - lastDow - (weeks - 1) * 7
    var out = []
    for (var i = 0; i < weeks * 7; i++) {
      var idx = start + i
      out.push(idx >= 0 && idx <= last ? list[idx] : null)
    }
    return out
  }

  Row {
    id: header
    spacing: 8
    Text {
      text: "󰊤"
      font.family: w.host.iconFamily
      font.pixelSize: 14
      color: w.fg
    }
    Text {
      text: w.user === "" ? w.host.tr("set githubUser in Customizer", "задай githubUser в Customizer")
        : w.error !== "" ? w.error
        : "@" + w.user + " · " + w.total + w.host.tr(" contributions this year", " вкладов за год")
      font.family: w.dot ? DotMatrix.Palette.fontLabel : w.host.fontFamily
      font.pixelSize: 12
      color: w.fg
      opacity: 0.75
    }
  }

  Grid {
    y: header.height + 10
    flow: Grid.TopToBottom
    rows: 7
    spacing: w.gap
    Repeater {
      model: w.grid.length > 0 ? w.weeks * 7 : 0
      Rectangle {
        required property int index
        readonly property var day: w.grid[index]
        width: w.cell; height: w.cell
        radius: w.dot ? w.cell / 2 : 2
        color: !day ? "transparent"
          : day.level > 0 ? Qt.rgba(w.accent.r, w.accent.g, w.accent.b, 0.25 + 0.1875 * day.level)
          : Qt.rgba(w.fg.r, w.fg.g, w.fg.b, 0.08)
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    enabled: w.user !== "" && !w.host.editMode
    cursorShape: Qt.PointingHandCursor
    onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/" + w.user])
  }
}

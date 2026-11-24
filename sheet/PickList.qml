import QtQuick

// Выпадающий список для строк выбора (Rice, Variant, Bar, Super+M, …) вместо «следующий по клику»: видно все варианты,
// ничего не применяется, пока не выбран. Кладётся поверх всей панели (одна штука на облик, Sk.list).
//   open(якорь, [{v, l}], текущее, cb(v), подпись) — под строкой (или над, если снизу мало места)
//   ↑↓ / j k — выделение, PgUp / PgDn, Home / End, буква — к первому на неё, Enter / Space / клик — выбрать, Esc — закрыть
// Вид — из Sk.t: popup "list" (карточка со скруглением, контуром и тенью облика) или "completion" (как всплывашка
// автодополнения в терминале: прямые углы, выбранная строка — инверсией, «>» слева).
Item {
  id: pl
  anchors.fill: parent
  z: 5000
  visible: opened || fade.running
  property bool opened: false
  property var options: []
  property var cur
  property var cb: null
  property string label: ""
  property int sel: 0
  property real ax: 0
  property real ay: 0
  property real aw: 200
  property real ah: 24
  readonly property bool term: Sk.s("popup", "list") === "completion"
  readonly property int rowH: Math.max(22, Sk.n("size", 12) + 14)
  readonly property int rows: Math.min(10, options.length)
  readonly property real boxH: rows * rowH + (label ? rowH : 0) + 10
  readonly property bool below: ay + ah + boxH + 8 < height || ay < boxH + 8
  property real k: 0
  NumberAnimation { id: fade; target: pl; property: "k"; duration: 130; easing.type: Easing.OutCubic }

  function lbl(o) { return String(o && o.l !== undefined ? o.l : o) }
  function val(o) { return o && o.v !== undefined ? o.v : o }
  function open(anchor, opts, current, done, caption) {
    options = opts || []
    cur = current
    cb = done
    label = caption || ""
    const p = anchor.mapToItem(pl, 0, 0)
    ax = p.x; ay = p.y; aw = Math.max(anchor.width, 180); ah = anchor.height
    sel = Math.max(0, options.findIndex(o => val(o) === current))
    opened = true
    fade.from = k; fade.to = 1; fade.restart()
    list.positionViewAtIndex(sel, ListView.Center)
  }
  function close() { if (!opened) return; opened = false; fade.from = k; fade.to = 0; fade.restart() }
  function accept(i) {
    const o = options[i === undefined ? sel : i]
    const f = cb
    close()
    if (o !== undefined && f) f(val(o))
  }
  function move(d) { if (options.length) { sel = Math.max(0, Math.min(options.length - 1, sel + d)); list.positionViewAtIndex(sel, ListView.Contain) } }
  // клавиши, пока список открыт: съедает всё (true)
  function keys(e) {
    const k = e.key
    if (k === Qt.Key_Escape) { close(); return true }
    if (k === Qt.Key_Down || k === Qt.Key_J || k === Qt.Key_Tab) { move(1); return true }
    if (k === Qt.Key_Up || k === Qt.Key_K || k === Qt.Key_Backtab) { move(-1); return true }
    if (k === Qt.Key_PageDown) { move(rows); return true }
    if (k === Qt.Key_PageUp) { move(-rows); return true }
    if (k === Qt.Key_Home) { sel = 0; list.positionViewAtIndex(0, ListView.Beginning); return true }
    if (k === Qt.Key_End) { sel = options.length - 1; list.positionViewAtIndex(sel, ListView.End); return true }
    if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) { accept(); return true }
    const ch = String(e.text || "").toLowerCase()
    if (ch.length === 1 && /[a-z0-9а-я]/.test(ch)) {
      for (let j = 1; j <= options.length; j++) {
        const i = (sel + j) % options.length
        if (lbl(options[i]).toLowerCase().startsWith(ch)) { sel = i; list.positionViewAtIndex(i, ListView.Contain); break }
      }
    }
    return true
  }

  // клик мимо — закрыть
  MouseArea { anchors.fill: parent; enabled: pl.opened; onClicked: pl.close(); onWheel: w => w.accepted = true }

  Item {
    id: box
    readonly property real w: Math.min(pl.width - 16, Math.max(pl.aw, 220))
    x: Math.max(8, Math.min(pl.ax, pl.width - w - 8))
    y: pl.below ? pl.ay + pl.ah + 4 : pl.ay - pl.boxH - 4
    width: w
    height: pl.boxH
    opacity: pl.k
    transform: Translate { y: (1 - pl.k) * (pl.below ? -8 : 8) }
    // жёсткая тень облика
    Rectangle {
      visible: Sk.n("shadow", 0) > 0
      x: Sk.n("shadow", 0); y: Sk.n("shadow", 0)
      width: parent.width; height: parent.height
      radius: pl.term ? 0 : Sk.n("radius", 6)
      color: Sk.c("shadowColor", "#000000")
    }
    Rectangle {
      anchors.fill: parent
      radius: pl.term ? 0 : Sk.n("radius", 6)
      color: Sk.c("card", Sk.c("bg", "#202020"))
      border.width: Math.max(1, Sk.n("border", 1))
      border.color: Sk.c("line", "#666666")
    }
    MouseArea { anchors.fill: parent; onWheel: w => pl.move(w.angleDelta.y < 0 ? 1 : -1) }
    Text {
      visible: pl.label !== ""
      x: 12; y: 5; height: pl.rowH
      verticalAlignment: Text.AlignVCenter
      text: pl.term ? "-- " + pl.label.toLowerCase() + " --" : Sk.cap(pl.label)
      color: Sk.c("dim", "#999999")
      font.family: Sk.s("font", "monospace"); font.pixelSize: Math.max(9, Sk.n("size", 12) - 2)
      font.letterSpacing: Sk.n("spacing", 0)
    }
    ListView {
      id: list
      x: 5; y: 5 + (pl.label ? pl.rowH : 0)
      width: parent.width - 10
      height: pl.rows * pl.rowH
      clip: true
      model: pl.options
      boundsBehavior: Flickable.StopAtBounds
      delegate: Item {
        id: row
        required property var modelData
        required property int index
        readonly property bool on: index === pl.sel
        readonly property bool used: pl.val(modelData) === pl.cur
        width: ListView.view.width
        height: pl.rowH
        Rectangle {
          anchors.fill: parent
          radius: pl.term ? 0 : Math.max(0, Sk.n("radius", 6) - 3)
          color: row.on ? Sk.c("sel", Sk.c("accent", "#888888")) : rh.containsMouse ? Sk.alpha(Sk.c("ink", "#ffffff"), 0.07) : "transparent"
        }
        Text {
          x: 10
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - 40
          elide: Text.ElideRight
          text: (pl.term ? (row.on ? "> " : "  ") : "") + Sk.cap(pl.lbl(row.modelData))
          color: row.on ? Sk.ink(Sk.c("sel", Sk.c("accent", "#888888"))) : row.used ? Sk.c("accent", "#ffffff") : Sk.c("ink", "#ffffff")
          font.family: Sk.s("font", "monospace"); font.pixelSize: Sk.n("size", 12)
          font.letterSpacing: Sk.n("spacing", 0)
          font.bold: row.used
        }
        Text {
          visible: row.used
          anchors.right: parent.right; anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          text: pl.term ? "*" : "✓"
          color: row.on ? Sk.ink(Sk.c("sel", Sk.c("accent", "#888888"))) : Sk.c("accent", "#ffffff")
          font.family: Sk.s("font", "monospace"); font.pixelSize: Sk.n("size", 12); font.bold: true
        }
        MouseArea { id: rh; anchors.fill: parent; hoverEnabled: true; onEntered: pl.sel = row.index; onClicked: pl.accept(row.index) }
      }
    }
    // полоса прокрутки, если вариантов больше, чем видно
    Rectangle {
      visible: pl.options.length > pl.rows
      x: parent.width - 4; width: 2; radius: 1
      y: list.y + list.visibleArea.yPosition * list.height
      height: Math.max(12, list.visibleArea.heightRatio * list.height)
      color: Sk.alpha(Sk.c("ink", "#ffffff"), 0.35)
    }
  }
}

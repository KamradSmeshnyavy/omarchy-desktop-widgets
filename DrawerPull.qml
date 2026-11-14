import QtQuick
import Quickshell
import Quickshell.Io

// Отрыв панели от бара (как Desk у Vitreus) — общий для дашборда, настроек и меню выключения. Панель тянут за язычок
// Retro или верхнюю полосу: перешеек тянется и рвётся, панель остаётся там, где отпустили. Отпустили:
//   у своего места у бара (ближе 80 px) — прилипает обратно;
//   у кромки рамки или бара (ближе 32 px) — встаёт к ней вплотную и сливается с ней (mergeEdges / strip / cut);
//   иначе — висит свободно.
// Место запоминается в ~/.config/omarchy/panel-places.json { key: { screen, x, y, edge } } — следующее открытие сразу
// там; вернул к бару — место забыто. Координаты — px экрана (окно панели — весь экран).
QtObject {
  id: p

  required property var dg               // DrawerGeom панели
  property string key: ""
  property string screenName: ""
  property real bodyWidth: 300
  property real bodyHeight: 300
  property real snapDist: 32

  property bool detached: false
  property bool pulling: false
  property point freePos: Qt.point(0, 0)
  property point pullBase: Qt.point(0, 0)
  property bool snapping: false
  property string edge: ""               // к какой кромке прилипла оторванная панель

  readonly property bool loose: detached || pulling
  readonly property real dist: loose ? Math.hypot(freePos.x - dg.endRect.x, freePos.y - dg.endRect.y) : 0
  readonly property rect rect: Qt.rect(freePos.x, freePos.y, bodyWidth, bodyHeight)
  readonly property bool stuck: detached && !pulling && edge !== "" && inset(edge) >= 0

  // расстояние от стороны экрана до внутренней кромки бара / рамки; -1 — с этой стороной не сливается
  function inset(e) {
    if (!dg.merge) return -1
    if (e === dg.edge) return e === "left" || e === "top" ? dg.inner : e === "right" ? dg.scrW - dg.inner : dg.scrH - dg.inner
    return dg.geo.framed ? dg.fw : -1
  }
  function gapTo(e, r) {
    var i = inset(e)
    if (i < 0) return 1e9
    return e === "left" ? r.x - i : e === "right" ? dg.scrW - i - (r.x + r.width)
      : e === "top" ? r.y - i : dg.scrH - i - (r.y + r.height)
  }
  function flush(e, pt) {
    var i = inset(e)
    if (e === "left") return Qt.point(i, pt.y)
    if (e === "right") return Qt.point(dg.scrW - i - bodyWidth, pt.y)
    if (e === "top") return Qt.point(pt.x, i)
    return Qt.point(pt.x, dg.scrH - i - bodyHeight)
  }

  function start(cur) {
    pullBase = Qt.point(cur.x, cur.y)
    freePos = pullBase
    edge = ""
    pulling = true
  }
  function move(tx, ty) {
    freePos = Qt.point(Math.max(0, Math.min(dg.scrW - bodyWidth, pullBase.x + tx)),
                       Math.max(0, Math.min(dg.scrH - bodyHeight, pullBase.y + ty)))
  }
  function end() {
    var near = dist < 80
    pulling = false
    snapping = true
    snapOff.restart()
    if (near) { home(); return }
    var best = "", bd = snapDist, r = rect, sides = ["left", "right", "top", "bottom"]
    for (var k = 0; k < sides.length; k++) {
      var d = Math.abs(gapTo(sides[k], r))
      if (d < bd) { bd = d; best = sides[k] }
    }
    if (best) freePos = flush(best, freePos)
    edge = best
    detached = true
    save({ screen: screenName, x: Math.round(freePos.x), y: Math.round(freePos.y), edge: best })
  }
  // обратно к бару, место забыто
  function home() {
    snapping = true
    snapOff.restart()
    detached = false
    edge = ""
    save(null)
  }
  // открытие: панель сразу на сохранённом месте
  function restore() {
    var s = places[key]
    if (!s || s.screen !== screenName) { detached = false; edge = ""; return }
    var x = Math.max(0, Math.min(dg.scrW - bodyWidth, Number(s.x) || 0))
    var y = Math.max(0, Math.min(dg.scrH - bodyHeight, Number(s.y) || 0))
    var e = s.edge && inset(String(s.edge)) >= 0 ? String(s.edge) : ""
    freePos = e ? flush(e, Qt.point(x, y)) : Qt.point(x, y)
    edge = e
    detached = true
  }

  // слияние прилипшей панели с кромкой (в px экрана): какой край слит, опора стекла вдоль кромки, вырез за ней
  readonly property var mergeEdges: stuck ? [edge] : []
  readonly property rect strip: {
    if (!stuck) return Qt.rect(0, 0, 0, 0)
    var t = 5, ex = dg.fillet + 6, i = inset(edge), r = rect
    if (edge === "top") return Qt.rect(r.x - ex, i - t, r.width + 2 * ex, t)
    if (edge === "bottom") return Qt.rect(r.x - ex, dg.scrH - i, r.width + 2 * ex, t)
    if (edge === "left") return Qt.rect(i - t, r.y - ex, t, r.height + 2 * ex)
    return Qt.rect(dg.scrW - i, r.y - ex, t, r.height + 2 * ex)
  }
  readonly property rect cut: {
    if (!stuck) return Qt.rect(0, 0, 0, 0)
    var c = inset(edge) - 3
    if (edge === "top") return Qt.rect(-4000, -4000, 8000 + dg.scrW, 4000 + c)
    if (edge === "bottom") return Qt.rect(-4000, dg.scrH - c, 8000 + dg.scrW, 4000 + c)
    if (edge === "left") return Qt.rect(-4000, -4000, 4000 + c, 8000 + dg.scrH)
    return Qt.rect(dg.scrW - c, -4000, 4000 + c, 8000 + dg.scrH)
  }

  property var places: ({})
  property Timer snapOff: Timer { interval: 360; onTriggered: p.snapping = false }
  property FileView file: FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/panel-places.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { var d = JSON.parse(text()); p.places = d && typeof d === "object" ? d : {} } catch (e) { p.places = {} } }
    onLoadFailed: p.places = {}
  }
  function save(place) {
    if (!key) return
    var o = Object.assign({}, places)
    if (place) o[key] = place
    else delete o[key]
    places = o
    file.setText(JSON.stringify(o, null, 2) + "\n")
  }
}

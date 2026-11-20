import QtQuick
import Quickshell
import Quickshell.Io

// Соседняя стеклянная карточка стола для панели в другом окне (как у Vitreus — панель и карточка рядом одним куском
// стекла): DesktopLayer пишет $XDG_RUNTIME_DIR/omarchy-desk-cards[-float]-<экран>.json ({x, y, w, h, r} в px экрана).
// rect — тело панели в px экрана; nb — ближайшая карточка не дальше 26 px сбоку (с перекрытием по другой оси больше
// 24 px) или null. Панель тянет к ней перешеек (glassJoin3) и не рисует поверх неё (glassCut3).
Item {
  id: n

  property string screenName: ""
  property rect rect: Qt.rect(0, 0, 0, 0)
  property bool active: false
  property var cards: []
  property var floats: []

  readonly property var nb: {
    if (!active || rect.width <= 0) return null
    var all = cards.concat(floats), best = null, bd = 27, r = rect
    for (var i = 0; i < all.length; i++) {
      var c = all[i]
      var ox = Math.min(r.x + r.width, c.x + c.w) - Math.max(r.x, c.x)
      var oy = Math.min(r.y + r.height, c.y + c.h) - Math.max(r.y, c.y)
      var gx = Math.max(c.x - (r.x + r.width), r.x - (c.x + c.w))
      var gy = Math.max(c.y - (r.y + r.height), r.y - (c.y + c.h))
      var g = oy > 24 && gx >= -2 ? gx : ox > 24 && gy >= -2 ? gy : 999
      if (g < bd) {
        bd = g
        // с какой стороны панели карточка: она дотягивается к панели на долю зазора (как у Vitreus: dl = (зазор − 14) / 50)
        var side = oy > 24 && gx >= -2 ? (c.x > r.x ? "right" : "left") : (c.y > r.y ? "below" : "above")
        best = { x: c.x, y: c.y, w: c.w, h: c.h, r: c.r, gap: Math.max(0, g), side: side }
      }
    }
    return best
  }
  readonly property real reach: nb ? nb.gap * (1 - Math.max(0, Math.min(1, (nb.gap - 14) / 50))) : 0
  // карточка вместе с дотягиванием — фигура, к которой тянется стекло панели
  function rel(origin) {
    if (!nb) return Qt.rect(0, 0, 0, 0)
    var x = nb.x - origin.x, y = nb.y - origin.y, w = nb.w, h = nb.h, e = reach
    if (nb.side === "above") h += e
    else if (nb.side === "below") { y -= e; h += e }
    else if (nb.side === "left") w += e
    else { x -= e; w += e }
    return Qt.rect(x, y, w, h)
  }
  // сама карточка — её стекло рисует она, панель поверх не рисует
  function cutRel(origin) { return nb ? Qt.rect(nb.x - origin.x, nb.y - origin.y, nb.w, nb.h) : Qt.rect(0, 0, 0, 0) }

  FileView {
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarchy-desk-cards-" + n.screenName + ".json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { n.cards = JSON.parse(text()) || [] } catch (e) { n.cards = [] } }
    onLoadFailed: n.cards = []
  }
  FileView {
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarchy-desk-cards-float-" + n.screenName + ".json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { n.floats = JSON.parse(text()) || [] } catch (e) { n.floats = [] } }
    onLoadFailed: n.floats = []
  }
}

import QtQuick

// Управление дашбордом и меню с клавиатуры. Кладётся поверх содержимого (anchors.fill), scope — где искать.
// Цели находятся сами (auto): всё, на что можно кликнуть, — MouseArea (кроме фоновых на всю область и без кнопок) и
// TapHandler (цель — его элемент); нажатие с клавиатуры шлёт им тот же clicked / tapped левой кнопкой. Явно — любой
// видимый элемент со свойством `kbdNav: true` и функцией `kbdPress()` (kbdNav: false — исключить); по желанию:
//   kbdAdjust(шаг) — ←/→ (h/l) меняют значение (ползунок), ↑/↓ уходят к соседям;
//   kbdRadius — скругление рамки выбора; kbdOrder — порядок для Tab (иначе — сверху вниз, слева направо).
// Клавиши: стрелки / hjkl — ближайшая цель в эту сторону, Tab / Shift+Tab — по порядку, Enter / Space — нажать,
// Home — первая. handle(event) зовёт держатель фокуса из Keys.onPressed; вернёт true, если клавиша съедена.
// Рамка появляется после первого нажатия и не мешает мыши. Цель внутри Flickable / ListView (список с прокруткой)
// докручивается в видимую часть; если её увели колесом за край — рамка прячется, а не висит поверх панели.
Item {
  id: nav
  property Item scope: parent
  property bool active: true
  property color ring: "#ffffff"
  property real ringWidth: 2
  property bool auto: true
  property bool vim: true      // hjkl как стрелки (false — если у панели свои буквы)
  property var current: null   // элемент; у TapHandler — сам обработчик (рамка — по его родителю)
  property bool shown: false
  onActiveChanged: if (!active) { shown = false; current = null; last = null }

  function isMouseArea(it) { return typeof it.pressAndHold === "function" && it.acceptedButtons !== undefined && it.pressed !== undefined }
  function isTap(o) { return o && typeof o.tapped === "function" && o.gesturePolicy !== undefined }
  function host(t) { return isTap(t) ? t.parent : t }
  function big(it) { return scope && it.width * it.height > scope.width * scope.height * 0.5 }
  function collect(item, out, seen) {
    if (!item || item === nav || !item.visible || item.opacity <= 0.01) return
    if (item.kbdNav === false) return
    if (item.enabled === false) return     // выключенная ветка (например, плитки под открытой карточкой)
    var took = false
    if (item.kbdNav === true && typeof item.kbdPress === "function" && item.width > 0) { out.push(item); took = true }
    else if (auto && item.width > 2 && item.height > 2 && !big(item)) {
      if (isMouseArea(item) && item.enabled && (item.acceptedButtons & Qt.LeftButton)) { out.push(item); took = true }
      else {
        var d = item.data
        for (var j = 0; j < d.length; j++) if (isTap(d[j]) && d[j].enabled) { out.push(d[j]); took = true; break }
      }
    }
    var ch = item.children
    for (var i = 0; i < ch.length; i++) collect(ch[i], out, seen)
  }
  // одна цель на место: вложенные с почти тем же прямоугольником — одна
  function targets() {
    var raw = []; collect(scope, raw)
    var out = []
    for (var i = 0; i < raw.length; i++) {
      var r = rectOf(raw[i]), dup = false
      for (var j = 0; j < out.length; j++) { var q = rectOf(out[j]); if (Math.abs(q.cx - r.cx) < 4 && Math.abs(q.cy - r.cy) < 4) { dup = true; break } }
      if (!dup) out.push(raw[i])
    }
    return out
  }
  function rectOf(t) { var it = host(t); var p = it.mapToItem(nav, 0, 0); return { x: p.x, y: p.y, w: it.width, h: it.height, cx: p.x + it.width / 2, cy: p.y + it.height / 2 } }
  // ближайший предок-прокрутка (Flickable, ListView, GridView) внутри scope
  function flickOf(it) {
    for (var p = it ? it.parent : null; p && p !== scope; p = p.parent)
      if (p.contentY !== undefined && p.contentHeight !== undefined && p.contentItem !== undefined && typeof p.flick === "function") return p
    return null
  }
  // докрутить все прокрутки над целью, чтобы она была видна целиком (с запасом pad)
  function reveal(t) {
    if (!t) return
    var it = host(t), pad = 8
    for (var f = flickOf(it); f; f = flickOf(f)) {
      var p = it.mapToItem(f.contentItem, 0, 0)
      var top = f.originY, maxY = f.originY + Math.max(0, f.contentHeight - f.height)
      if (f.contentHeight > f.height) {
        if (p.y - pad < f.contentY) f.contentY = Math.max(top, p.y - pad)
        else if (p.y + it.height + pad > f.contentY + f.height) f.contentY = Math.min(maxY, p.y + it.height + pad - f.height)
      }
      if (f.contentWidth > f.width && f.contentX !== undefined) {
        var maxX = f.originX + Math.max(0, f.contentWidth - f.width)
        if (p.x - pad < f.contentX) f.contentX = Math.max(f.originX, p.x - pad)
        else if (p.x + it.width + pad > f.contentX + f.width) f.contentX = Math.min(maxX, p.x + it.width + pad - f.width)
      }
      it = f
    }
  }
  // видна ли цель внутри своих прокруток
  function inView(t) {
    var it = host(t)
    for (var f = flickOf(it); f; f = flickOf(f)) {
      var p = it.mapToItem(f, 0, 0)
      if (p.y + it.height < 2 || p.y > f.height - 2 || p.x + it.width < 2 || p.x > f.width - 2) return false
    }
    return true
  }
  function press(t) {
    if (typeof t.kbdPress === "function") t.kbdPress()
    else if (isTap(t)) t.tapped(undefined, Qt.LeftButton)
    else if (isMouseArea(t)) t.clicked({ button: Qt.LeftButton, buttons: Qt.LeftButton, x: t.width / 2, y: t.height / 2, modifiers: 0, accepted: true, wasHeld: false })
  }
  function ordered() {
    var t = targets().map(function(it) { return { it: it, r: rectOf(it) } })
    t.sort(function(a, b) {
      var oa = a.it.kbdOrder !== undefined ? a.it.kbdOrder : 1e6, ob = b.it.kbdOrder !== undefined ? b.it.kbdOrder : 1e6
      if (oa !== ob) return oa - ob
      return Math.abs(a.r.cy - b.r.cy) > 12 ? a.r.cy - b.r.cy : a.r.cx - b.r.cx
    })
    return t.map(function(x) { return x.it })
  }
  function valid() { return !!current && targets().indexOf(current) !== -1 }
  // цель пропала (список пересоздал строки) — взять ту, что ближе всего к прежнему месту рамки
  property var last: null
  function recover() {
    if (valid()) return true
    if (!last) return false
    var t = targets(), best = null, bd = 1e12
    for (var i = 0; i < t.length; i++) {
      var r = rectOf(t[i]), d = Math.abs(r.cx - last.cx) + Math.abs(r.cy - last.cy) * 2
      if (d < bd) { bd = d; best = t[i] }
    }
    if (best && bd < 80) { current = best; return true }
    return false
  }
  function first() { var o = ordered(); current = o.length ? o[0] : null }
  function move(dx, dy) {
    if (!recover()) { first(); return }
    var c = rectOf(current), best = null, bestScore = 1e12
    var t = targets()
    for (var i = 0; i < t.length; i++) {
      if (t[i] === current) continue
      var r = rectOf(t[i]), vx = r.cx - c.cx, vy = r.cy - c.cy
      var along = dx !== 0 ? vx * dx : vy * dy
      if (along <= 2) continue
      var across = dx !== 0 ? Math.abs(vy) : Math.abs(vx)
      // перекрываются ли полосы — тогда соседа по линии предпочитаем
      var overlap = dx !== 0 ? (r.y < c.y + c.h && r.y + r.h > c.y) : (r.x < c.x + c.w && r.x + r.w > c.x)
      var score = along + across * (overlap ? 0.5 : 3)
      if (score < bestScore) { bestScore = score; best = t[i] }
    }
    if (best) current = best
  }
  function step(d) {
    var o = ordered()
    if (!o.length) return
    recover()
    var i = o.indexOf(current)
    current = o[(i < 0 ? 0 : i + d + o.length) % o.length]
  }
  function handle(e) {
    if (!active) return false
    var k = e.key, shift = (e.modifiers & Qt.ShiftModifier) !== 0
    var dir = ({})
    dir[Qt.Key_Left] = [-1, 0]; dir[Qt.Key_Right] = [1, 0]; dir[Qt.Key_Up] = [0, -1]; dir[Qt.Key_Down] = [0, 1]
    if (vim) { dir[Qt.Key_H] = [-1, 0]; dir[Qt.Key_L] = [1, 0]; dir[Qt.Key_K] = [0, -1]; dir[Qt.Key_J] = [0, 1] }
    if (dir[k]) {
      shown = true
      var d = dir[k]
      if (d[0] !== 0 && recover() && typeof current.kbdAdjust === "function") { current.kbdAdjust(d[0]); return true }
      move(d[0], d[1]); return true
    }
    if (k === Qt.Key_Tab || k === Qt.Key_Backtab) { shown = true; step(k === Qt.Key_Backtab || shift ? -1 : 1); return true }
    if (k === Qt.Key_Home) { shown = true; first(); return true }
    if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
      if (!recover()) { shown = true; first(); return true }
      press(current); return true
    }
    return false
  }

  // рамка выбора
  Rectangle {
    id: ringR
    visible: nav.shown && nav.active && !!nav.current && seen
    property bool seen: true
    property var r: ({ x: 0, y: 0, w: 0, h: 0 })
    Connections { target: nav; function onCurrentChanged() { if (nav.current) { nav.reveal(nav.current); ringR.seen = true; ringR.r = nav.rectOf(nav.current); nav.last = ringR.r } } }
    x: r.x - 4; y: r.y - 4; width: r.w + 8; height: r.h + 8
    radius: nav.current && nav.host(nav.current).kbdRadius !== undefined ? nav.host(nav.current).kbdRadius + 4 : nav.current && nav.host(nav.current).radius !== undefined ? nav.host(nav.current).radius + 4 : 6
    color: "transparent"
    border.width: nav.ringWidth
    border.color: nav.ring
    z: 1000
    // тонкий контрастный ободок снаружи — рамку видно на любом фоне
    Rectangle {
      anchors.fill: parent; anchors.margins: -1.5
      radius: parent.radius + 1.5; color: "transparent"; border.width: 1
      border.color: 0.299 * nav.ring.r + 0.587 * nav.ring.g + 0.114 * nav.ring.b > 0.5 ? Qt.rgba(0, 0, 0, 0.6) : Qt.rgba(1, 1, 1, 0.6)
    }
    Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
  }
  // позиция цели может меняться (анимации) — перечитываем
  Timer { interval: 120; repeat: true; running: nav.shown && nav.active && !!nav.current
    onTriggered: {
      if (!nav.current) return
      try { ringR.seen = nav.inView(nav.current); ringR.r = nav.rectOf(nav.current); nav.last = ringR.r }
      catch (e) { if (!nav.recover()) ringR.seen = false }   // строку удалили — рамку на соседнюю на том же месте
    } }
}

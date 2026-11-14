import QtQuick

// Геометрия панели, растущей из бара (как у Vitreus и caelestia, код свой) — общая для дашборда, Quick и меню выключения.
// Всё в логических px экрана (окно панели — весь экран). Панель встаёт против своей кнопки бара (anchorIds — id модулей
// из omarchy-bar-geom.json; нет кнопки — середина бара) и растёт из куска пилюли под ней (startRect → endRect, morph).
//   merge — бар во всю длину края (full, frame): панель вплотную к его кромке, одним куском с ним — перешеек вдоль всей
//           стороны панели даёт вогнутые изгибы; у рамки панель, оказавшаяся у её кромки, прилипает и к ней («крылья»);
//   иначе (плавающая пилюля, острова) — зазор gap и узкий перешеек, как капля.
// cut / cut2 — где стекло панели не рисовать: внутри бара и рамки (там своё стекло), с нахлёстом 3 px на их кромку.
QtObject {
  id: d

  required property var geo            // BarGeom
  property real bodyWidth: 300
  property real bodyHeight: 300
  property real progress: 0
  property var anchorIds: []
  property real scrW: 1440
  property real scrH: 900
  property real gap: 10
  property real fillet: 16

  readonly property string edge: geo.edge
  readonly property bool sideBar: edge === "left" || edge === "right"
  readonly property bool merge: !geo.floatingPill && geo.barLayer.width > 0
  readonly property real fw: geo.framed ? geo.frameWidth : 0
  readonly property rect pill: geo.pill
  // внутренняя кромка бара (линия, к которой панель прилипает)
  readonly property real inner: edge === "top" ? pill.y + pill.height : edge === "bottom" ? pill.y
    : edge === "left" ? pill.x + pill.width : pill.x
  readonly property real off: merge ? 0 : gap

  // кнопка панели на баре и середина вдоль бара
  readonly property rect button: { geo.exported; return geo.moduleRect(anchorIds) }
  readonly property bool hasButton: button.width > 0
  readonly property real along: hasButton ? (sideBar ? button.y + button.height / 2 : button.x + button.width / 2) : (sideBar ? scrH / 2 : scrW / 2)
  // рабочая область вдоль бара
  readonly property real lo: (sideBar ? (edge === "left" || edge === "right" ? fw : 0) : fw) + (merge ? 0 : 8)
  readonly property real hi: (sideBar ? scrH : scrW) - lo
  readonly property real len: sideBar ? bodyHeight : bodyWidth
  readonly property real snap: 48       // ближе к кромке рамки — прилипает к ней
  readonly property real a0: {
    var a = Math.max(lo, Math.min(hi - len, along - len / 2))
    if (geo.framed && merge) {
      if (a - lo < snap) a = lo
      if (hi - (a + len) < snap) a = hi - len
    }
    return a
  }
  // к каким кромкам рамки панель прилипла (по бокам вдоль бара)
  readonly property bool wingLo: geo.framed && merge && a0 <= lo + 0.5
  readonly property bool wingHi: geo.framed && merge && a0 + len >= hi - 0.5

  readonly property rect endRect: edge === "top" ? Qt.rect(a0, inner + off, bodyWidth, bodyHeight)
    : edge === "bottom" ? Qt.rect(a0, inner - off - bodyHeight, bodyWidth, bodyHeight)
    : edge === "left" ? Qt.rect(inner + off, a0, bodyWidth, bodyHeight)
    : Qt.rect(inner - off - bodyWidth, a0, bodyWidth, bodyHeight)

  // начало: кусок пилюли под кнопкой
  readonly property real s: hasButton ? Math.max(60, Math.min(240, sideBar ? button.height : button.width)) : Math.min(240, sideBar ? pill.height : pill.width)
  readonly property real sa: Math.max(sideBar ? pill.y : pill.x, Math.min((sideBar ? pill.y + pill.height : pill.x + pill.width) - s, along - s / 2))
  readonly property rect startRect: !sideBar ? Qt.rect(sa, pill.y, s, pill.height) : Qt.rect(pill.x, sa, pill.width, s)

  readonly property real m: Math.max(0, progress)
  readonly property real mw: Math.min(1.03, m * 1.35)
  readonly property real mh: Math.pow(Math.min(1.04, m), 1.35)
  readonly property real mAlongX: sideBar ? mh : mw
  readonly property real mAlongY: sideBar ? mw : mh
  readonly property rect morph: Qt.rect(startRect.x + (endRect.x - startRect.x) * Math.min(1, mAlongX), startRect.y + (endRect.y - startRect.y) * Math.min(1, mAlongY),
                                        startRect.width + (endRect.width - startRect.width) * mAlongX, startRect.height + (endRect.height - startRect.height) * mAlongY)

  // опора перешейка у внутренней кромки бара: при merge — вдоль всей стороны панели и ещё на изгиб с каждой стороны
  function neckFor(r) {
    var t = 5
    if (merge) {
      var e = fillet + 6
      return sideBar ? Qt.rect(edge === "left" ? inner - t : inner, r.y - e, t, r.height + 2 * e)
                     : Qt.rect(r.x - e, edge === "top" ? inner - t : inner, r.width + 2 * e, t)
    }
    return sideBar ? Qt.rect(edge === "left" ? inner - t : inner, along - 70, t, 140)
                   : Qt.rect(along - 70, edge === "top" ? inner - t : inner, 140, t)
  }
  readonly property real neckK: merge ? fillet : 26

  // крыло: кусок кромки рамки, к которой прилипла панель (поперёк бара)
  readonly property rect wing: {
    if (!wingLo && !wingHi) return Qt.rect(0, 0, 0, 0)
    var t = 5, e = fillet + 6, r = endRect
    if (!sideBar) {
      var x = wingLo ? fw - t : scrW - fw
      return Qt.rect(x, r.y - e, t, r.height + 2 * e)
    }
    var y = wingLo ? fw - t : scrH - fw
    return Qt.rect(r.x - e, y, r.width + 2 * e, t)
  }
  // вырезы: бар (от его внутренней кромки минус 3 px наружу) и кромка рамки у крыла
  readonly property rect cut: edge === "top" ? Qt.rect(-4000, -4000, 8000 + scrW, 4000 + inner - 3)
    : edge === "bottom" ? Qt.rect(-4000, inner + 3, 8000 + scrW, 4000 + scrH)
    : edge === "left" ? Qt.rect(-4000, -4000, 4000 + inner - 3, 8000 + scrH)
    : Qt.rect(inner + 3, -4000, 4000 + scrW, 8000 + scrH)
  readonly property rect cut2: {
    if (!wingLo && !wingHi) return Qt.rect(0, 0, 0, 0)
    var c = Math.max(0, fw - 3)
    if (!sideBar) return wingLo ? Qt.rect(-4000, -4000, 4000 + c, 8000 + scrH) : Qt.rect(scrW - c, -4000, 4000 + c, 8000 + scrH)
    return wingLo ? Qt.rect(-4000, -4000, 8000 + scrW, 4000 + c) : Qt.rect(-4000, scrH - c, 8000 + scrW, 4000 + c)
  }
  // какие края панели слиты (пластик): со стороны бара и у крыла
  readonly property var mergeEdges: {
    if (!merge) return []
    var out = [({ top: "top", bottom: "bottom", left: "left", right: "right" })[edge]]
    if (wingLo) out.push(sideBar ? "top" : "left")
    if (wingHi) out.push(sideBar ? "bottom" : "right")
    return out
  }
}

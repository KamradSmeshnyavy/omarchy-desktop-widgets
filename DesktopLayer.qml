import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Слой виджетов рабочего стола на одном экране (Widgets.qml создаёт по одному на экран).
//   floating = false — обычный слой: Bottom, над обоями и под окнами, клики проходят насквозь
//                      (кроме карточек плеера, todo, цитаты и фото);
//   floating = true  — слой «поверх окон» (Top): только свободные виджеты с <name>Float = true,
//                      как плавающее окно — открепил карточку и она висит над приложениями.
// Позиция: якорь <name>Anchor (top-left … bottom-right, center — колонкой) или "free" — центр
// <name>Pos { cx, cy, screen } в долях экрана. Режим правки (host.editMode): обычный слой поднимается
// на Top и ловит ввод целиком — виджеты тащатся мышью (DragHandle), ПКМ — меню, Esc — готово.
PanelWindow {
  id: desk

  required property var host            // Widgets.qml
  required property var modelData       // экран
  property bool floating: false

  readonly property string screenName: modelData ? String(modelData.name) : ""
  readonly property bool editing: host.editMode && !floating

  screen: modelData
  anchors { top: true; bottom: true; left: true; right: true }
  // Внутри бара и рамки: виджеты не уходят под них, отступ edgeMargin — от их внутреннего края.
  exclusionMode: ExclusionMode.Normal
  color: "transparent"
  surfaceFormat.opaque: false
  WlrLayershell.namespace: floating ? "omarchy-widgets-float" : "omarchy-widgets"
  WlrLayershell.layer: floating || editing ? WlrLayer.Top : WlrLayer.Bottom
  WlrLayershell.keyboardFocus: editing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  // Клики — только по интерактивным карточкам (на плавающем слое — по всем его виджетам);
  // в режиме правки — весь экран.
  mask: Region {
    // пока виджет держат (DirectGrab тянет или растягивает) — весь экран: курсор уходит за край виджета
    regions: desk.editing ? [editRegion] : desk.holding ? [allRegion]
      : desk.floating ? [gClock, gMedia, gSys, gNet, gTodo, gQuote, gPhoto, gContrib, menuRegion]
      : desk.host.value("directMove") !== false ? [gClock, gMedia, gSys, gNet, gTodo, gQuote, gPhoto, gContrib]
      : [rMedia, rTodo, rQuote, rPhoto, rContrib]
  }
  Region { id: editRegion; item: editArea }
  Region { id: allRegion; x: 0; y: 0; width: desk.width; height: desk.height }
  Region { id: gClock; item: g_clock.visible ? g_clock : null }
  Region { id: gMedia; item: g_media.visible ? g_media : null }
  Region { id: gSys; item: g_sysinfo.visible ? g_sysinfo : null }
  Region { id: gNet; item: g_network.visible ? g_network : null }
  Region { id: gTodo; item: g_todo.visible ? g_todo : null }
  Region { id: gQuote; item: g_quote.visible ? g_quote : null }
  Region { id: gPhoto; item: g_photo.visible ? g_photo : null }
  Region { id: gContrib; item: g_contrib.visible ? g_contrib : null }
  Region { id: menuRegion; item: menu.visible ? menu : null }
  Region { id: rClock; item: clockW.visible ? clockW : null }
  Region { id: rMedia; item: media.visible ? media : null }
  Region { id: rSys; item: sysW.visible ? sysW : null }
  Region { id: rNet; item: netW.visible ? netW : null }
  Region { id: rTodo; item: todoW.visible ? todoW : null }
  Region { id: rQuote; item: quoteW.visible ? quoteW : null }
  Region { id: rPhoto; item: photoW.visible ? photoW : null }
  Region { id: rContrib; item: contribW.visible ? contribW : null }

  // ── Что показывать на этом слое ──
  function isFree(name) { return String(host.value(name + "Anchor")) === "free" }
  function onThisScreen(name) {
    var p = host.value(name + "Pos")
    var s = p && typeof p === "object" ? String(p.screen || "") : ""
    // Экран не задан или такого больше нет — на первом.
    if (s === "" || !Quickshell.screens.some(function(x) { return x.name === s }))
      return Quickshell.screens.length === 0 || Quickshell.screens[0].name === screenName
    return s === screenName
  }
  function shows(name) {
    var free = isFree(name)
    var fl = free && host.flag(name + "Float")
    // В режиме правки всё на обычном слое (он тогда на Top и ловит ввод целиком): плавающий слой
    // оказался бы под ним, и до открепленного виджета было бы не дотянуться.
    if (floating) return fl && !host.editMode && onThisScreen(name)
    if (fl && !host.editMode) return false
    if (!free) return host.editMode || (!host.deskOff && !host.homeHides(screenName))
    return onThisScreen(name)
  }

  function label(name) {
    return ({
      contrib: "GitHub", clock: host.tr("Clock", "Часы"), media: host.tr("Player", "Плеер"), sysinfo: host.tr("System", "Система"),
      network: host.tr("Network", "Сеть"), todo: "Todo", quote: host.tr("Quote", "Цитата"), photo: host.tr("Photo", "Фото")
    })[name] || name
  }

  // Пока тащим — позиция виджета с этим якорем отсюда, а не из конфига.
  property string dragKey: ""
  // Размер виджета (<name>Scale, тянут за угол — DirectGrab): пока тянут — liveScale у scaleKey.
  property string scaleKey: ""
  readonly property bool holding: dragKey !== "" || scaleKey !== ""
  property real liveScale: 1
  function scaleOf(name) {
    if (scaleKey === name) return liveScale
    var v = Number(host.value(name + "Scale"))
    return isFinite(v) && v > 0 ? v : 1
  }
  // ── Слияние с баром и рамкой (как у Vitreus) ──
  // Края окна слоя — внутренние кромки бара и рамки (окно не заходит под них). У каких из них карточка сливается:
  // у рамки — у всех четырёх, у сплошного бара во всю длину края — у него; у плавающей пилюли — ни у каких.
  // Карточка с якорем у такого края встаёт вплотную (без edgeMargin), отпущенная рядом — прилипает.
  BarGeom { id: bgeo }
  readonly property bool mergeOn: host.value("edgeMerge") !== false && carded && host.deskStyle.card && bgeo.exported.position !== undefined
  readonly property var mergeable: !mergeOn ? [] : bgeo.framed ? ["top", "bottom", "left", "right"]
    : !bgeo.floatingPill && bgeo.exported.hidden !== true ? [String(bgeo.exported.position)] : []
  function mOf(side) { return mergeable.indexOf(side) !== -1 ? 0 : host.num("edgeMargin") }

  // Места стыков — рамке (ScreenBorder в бар-плагине): слой виджетов под ней, свой контур на стыке она стирает сама.
  // $XDG_RUNTIME_DIR/omarchy-merge-widgets[-float]-<экран>.json: [{ edge, a0, a1, f }] в px рабочей области.
  property string spotsText: ""
  function exportSpots() {
    var out = [], kids = desk.contentItem.children
    for (var i = 0; i < kids.length; i++) {
      var c = kids[i]
      if (!c || !c.visible || c.mergeEdges === undefined || !c.mergeEdges.length) continue
      for (var j = 0; j < c.mergeEdges.length; j++) {
        var e = c.mergeEdges[j], v = e === "top" || e === "bottom"
        out.push({ edge: e, a0: Math.round(v ? c.x : c.y), a1: Math.round(v ? c.x + c.width : c.y + c.height), f: 14 })
      }
    }
    var t = JSON.stringify(out)
    if (t === spotsText) return
    spotsText = t
    spotsFile.setText(t + "\n")
  }
  FileView {
    id: spotsFile
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarchy-merge-widgets" + (desk.floating ? "-float-" : "-") + desk.screenName + ".json"
    printErrors: false
  }
  Timer { interval: 700; running: true; repeat: true; triggeredOnStart: true; onTriggered: desk.exportSpots() }

  property point dragPt: Qt.point(0, 0)
  readonly property int grid: 8
  // Привязка: к сетке 8 px и к отступу edgeMargin от краёв, не за пределы экрана.
  function snap(x, y, item) {
    var m = host.num("edgeMargin")
    var w = item.width, h = item.height
    x = Math.round(x / grid) * grid
    y = Math.round(y / grid) * grid
    if (Math.abs(x - m) < grid * 2) x = m
    if (Math.abs(x + w - (width - m)) < grid * 2) x = width - m - w
    if (Math.abs(y - m) < grid * 2) y = m
    if (Math.abs(y + h - (height - m)) < grid * 2) y = height - m - h
    // у сливающихся краёв карточка (виджет с полями p) прилипает вплотную, если отпущена ближе 32 px
    var p = padOf(item)
    if (mergeable.indexOf("left") !== -1 && x - p < 32) x = p
    if (mergeable.indexOf("right") !== -1 && width - (x + w + p) < 32) x = width - w - p
    if (mergeable.indexOf("top") !== -1 && y - p < 32) y = p
    if (mergeable.indexOf("bottom") !== -1 && height - (y + h + p) < 32) y = height - h - p
    return Qt.point(Math.max(0, Math.min(width - w, x)), Math.max(0, Math.min(height - h, y)))
  }

  Visualizer {
    host: desk.host
    visible: !desk.floating && desk.host.flag("visualizer") && desk.host.levels.length > 0
    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
    height: Math.max(40, desk.host.num("visualizerHeight"))
  }

  // Режим правки: точечная сетка и подсказка сверху; клик по пустому месту закрывает меню.
  Item {
    id: editArea
    anchors.fill: parent
    visible: desk.editing
    focus: desk.editing
    Keys.onEscapePressed: { if (menu.visible) desk.closeMenu(); else desk.host.editMode = false }
    Keys.onReturnPressed: desk.host.editMode = false

    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.18) }
    Grid {
      anchors.fill: parent
      anchors.margins: desk.grid * 4
      columns: Math.floor(width / (desk.grid * 4)) + 1
      Repeater {
        model: desk.editing ? Math.ceil(editArea.width / (desk.grid * 4)) * Math.ceil(editArea.height / (desk.grid * 4)) : 0
        Item {
          width: desk.grid * 4; height: desk.grid * 4
          Rectangle { width: 2; height: 2; radius: 1; color: desk.host.foreground; opacity: 0.22 }
        }
      }
    }
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onPressed: desk.closeMenu()
    }
    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      y: 24
      height: hint.implicitHeight + 16
      width: hint.implicitWidth + 32
      radius: height / 2
      color: desk.host.background
      border.width: 1
      border.color: desk.host.accent
      Text {
        id: hint
        anchors.centerIn: parent
        text: desk.host.tr("Drag widgets · right click — menu · Esc / Enter — done",
                            "Перетаскивай виджеты · ПКМ — меню · Esc / Enter — готово")
        font.family: desk.host.fontFamily
        font.pixelSize: 14
        color: desk.host.foreground
      }
    }
  }

  WidgetCard { host: desk.host; mergeable: desk.mergeable; glassNs: desk.floating ? "omarchy-widgets-float" : "omarchy-widgets"; glassBelowWin: !desk.floating; target: clockW; noCard: desk.host.value("clockStyle") === "vitreus"; s: desk.scaleOf("clock"); seed: 21; pad: desk.padOf(clockW) }
  WidgetCard { host: desk.host; mergeable: desk.mergeable; glassNs: desk.floating ? "omarchy-widgets-float" : "omarchy-widgets"; glassBelowWin: !desk.floating; target: media; s: desk.scaleOf("media"); seed: 22; pad: desk.padOf(media); ownDotmatrixCard: true }
  WidgetCard { host: desk.host; mergeable: desk.mergeable; glassNs: desk.floating ? "omarchy-widgets-float" : "omarchy-widgets"; glassBelowWin: !desk.floating; target: sysW; s: desk.scaleOf("sysinfo"); seed: 23; pad: desk.padOf(sysW) }
  WidgetCard { host: desk.host; mergeable: desk.mergeable; glassNs: desk.floating ? "omarchy-widgets-float" : "omarchy-widgets"; glassBelowWin: !desk.floating; target: netW; s: desk.scaleOf("network"); seed: 27; pad: desk.padOf(netW) }
  WidgetCard { host: desk.host; mergeable: desk.mergeable; glassNs: desk.floating ? "omarchy-widgets-float" : "omarchy-widgets"; glassBelowWin: !desk.floating; target: todoW; s: desk.scaleOf("todo"); seed: 24; pad: desk.padOf(todoW) }
  WidgetCard { host: desk.host; mergeable: desk.mergeable; glassNs: desk.floating ? "omarchy-widgets-float" : "omarchy-widgets"; glassBelowWin: !desk.floating; target: quoteW; s: desk.scaleOf("quote"); seed: 25; pad: desk.padOf(quoteW) }
  WidgetCard { host: desk.host; mergeable: desk.mergeable; glassNs: desk.floating ? "omarchy-widgets-float" : "omarchy-widgets"; glassBelowWin: !desk.floating; target: photoW; s: desk.scaleOf("photo"); seed: 26; pad: desk.padOf(photoW) }
  WidgetCard { host: desk.host; mergeable: desk.mergeable; glassNs: desk.floating ? "omarchy-widgets-float" : "omarchy-widgets"; glassBelowWin: !desk.floating; target: contribW; s: desk.scaleOf("contrib"); seed: 28; pad: desk.padOf(contribW) }

  NetWidget {
    id: netW
    host: desk.host
    visible: desk.host.flag("network") && desk.shows("network")
    x: desk.place(netW, "networkAnchor").x
    scale: desk.scaleOf("network")
    y: desk.place(netW, "networkAnchor").y
  }
  TodoWidget {
    id: todoW
    host: desk.host
    visible: desk.host.flag("todo") && desk.shows("todo")
    x: desk.place(todoW, "todoAnchor").x
    scale: desk.scaleOf("todo")
    y: desk.place(todoW, "todoAnchor").y
  }
  QuoteWidget {
    id: quoteW
    host: desk.host
    visible: desk.host.flag("quote") && desk.shows("quote")
    x: desk.place(quoteW, "quoteAnchor").x
    scale: desk.scaleOf("quote")
    y: desk.place(quoteW, "quoteAnchor").y
  }
  PhotoWidget {
    id: photoW
    host: desk.host
    visible: desk.host.flag("photo") && desk.shows("photo")
    x: desk.place(photoW, "photoAnchor").x
    scale: desk.scaleOf("photo")
    y: desk.place(photoW, "photoAnchor").y
  }
  ContribWidget {
    id: contribW
    host: desk.host
    visible: desk.host.flag("contrib") && desk.shows("contrib")
    x: desk.place(contribW, "contribAnchor").x
    scale: desk.scaleOf("contrib")
    y: desk.place(contribW, "contribAnchor").y
  }
  ClockWidget {
    id: clockW
    host: desk.host
    visible: desk.host.flag("clock") && desk.shows("clock")
    x: desk.place(clockW, "clockAnchor").x
    scale: desk.scaleOf("clock")
    y: desk.place(clockW, "clockAnchor").y
  }
  MediaWidget {
    id: media
    host: desk.host
    // DOT-MATRIX — как в NIHIL: карточка всегда на месте, без плеера кнопки приглушены.
    // Открепленная карточка тоже всегда на месте — пропадающее «окно» сбивает с толку.
    visible: desk.host.flag("media") && desk.shows("media")
      && (desk.host.dotmatrixWidgets || desk.isFree("media") || (desk.host.player !== null && desk.host.player.trackTitle !== ""))
    x: desk.place(media, "mediaAnchor").x
    scale: desk.scaleOf("media")
    y: desk.place(media, "mediaAnchor").y
  }
  SysInfo {
    id: sysW
    host: desk.host
    visible: desk.host.flag("sysinfo") && desk.shows("sysinfo")
    x: desk.place(sysW, "sysinfoAnchor").x
    scale: desk.scaleOf("sysinfo")
    y: desk.place(sysW, "sysinfoAnchor").y
  }

  // Ручки режима правки — поверх всех виджетов.
  DragHandle { host: desk.host; desk: desk; target: clockW; name: "clock"; pad: desk.padOf(clockW) }
  DragHandle { host: desk.host; desk: desk; target: media; name: "media"; pad: desk.padOf(media) }
  DragHandle { host: desk.host; desk: desk; target: sysW; name: "sysinfo"; pad: desk.padOf(sysW) }
  DragHandle { host: desk.host; desk: desk; target: netW; name: "network"; pad: desk.padOf(netW) }
  DragHandle { host: desk.host; desk: desk; target: todoW; name: "todo"; pad: desk.padOf(todoW) }
  DragHandle { host: desk.host; desk: desk; target: quoteW; name: "quote"; pad: desk.padOf(quoteW) }
  DragHandle { host: desk.host; desk: desk; target: photoW; name: "photo"; pad: desk.padOf(photoW) }
  DragHandle { host: desk.host; desk: desk; target: contribW; name: "contrib"; pad: desk.padOf(contribW) }

  // Перенос без режима правки: взять и тянуть, углы — размер, булавка — на место (DirectGrab).
  DirectGrab { id: g_clock; host: desk.host; desk: desk; target: clockW; name: "clock"; pad: desk.padOf(clockW) }
  DirectGrab { id: g_media; host: desk.host; desk: desk; target: media; name: "media"; pad: desk.padOf(media) }
  DirectGrab { id: g_sysinfo; host: desk.host; desk: desk; target: sysW; name: "sysinfo"; pad: desk.padOf(sysW) }
  DirectGrab { id: g_network; host: desk.host; desk: desk; target: netW; name: "network"; pad: desk.padOf(netW) }
  DirectGrab { id: g_todo; host: desk.host; desk: desk; target: todoW; name: "todo"; pad: desk.padOf(todoW) }
  DirectGrab { id: g_quote; host: desk.host; desk: desk; target: quoteW; name: "quote"; pad: desk.padOf(quoteW) }
  DirectGrab { id: g_photo; host: desk.host; desk: desk; target: photoW; name: "photo"; pad: desk.padOf(photoW) }
  DirectGrab { id: g_contrib; host: desk.host; desk: desk; target: contribW; name: "contrib"; pad: desk.padOf(contribW) }

  // Плавающий слой: при наведении на открепленный виджет — кнопки «переместить» (режим правки) и
  // «вернуть на место». HoverHandler пассивный: кнопки самого виджета (плеер) продолжают работать.
  Repeater {
    model: desk.floating ? desk.entries : []
    delegate: Item {
      id: fc
      required property var modelData
      readonly property Item w: modelData[0]
      readonly property string name: String(modelData[1]).replace(/Anchor$/, "")
      readonly property int p: desk.padOf(w)
      visible: w.visible
      x: w.x - p; y: w.y - p
      width: w.width + 2 * p; height: w.height + 2 * p
      z: 60
      HoverHandler { id: hov }
      Row {
        anchors { top: parent.top; right: parent.right; margins: 6 }
        spacing: 4
        opacity: hov.hovered ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
        Repeater {
          model: [
            { icon: "󰆾", act: "edit", tip: desk.host.tr("Move", "Переместить") },
            { icon: "󰐄", act: "dock", tip: desk.host.tr("Back to its place", "Вернуть на место") }
          ]
          delegate: Rectangle {
            required property var modelData
            width: 26; height: 26; radius: 13
            color: bm.containsMouse ? desk.host.accent : desk.host.background
            border.width: 1
            border.color: Qt.rgba(desk.host.foreground.r, desk.host.foreground.g, desk.host.foreground.b, 0.25)
            Text {
              anchors.centerIn: parent
              text: parent.modelData.icon
              font.family: desk.host.iconFamily
              font.pixelSize: 13
              color: bm.containsMouse ? desk.host.background : desk.host.foreground
            }
            MouseArea {
              id: bm
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (parent.modelData.act === "dock") desk.host.dock(fc.name)
                else desk.host.editMode = true
              }
            }
          }
        }
      }
    }
  }

  // Подложки есть (стиль Customizer или DOT-MATRIX) — поля карточки вокруг виджета.
  readonly property bool carded: host.styledWidgets || host.dotmatrixWidgets
  function padOf(item) {
    if (!carded) return 0
    if (item === media) return host.dotmatrixWidgets ? 0 : 6   // у плеера DOT-MATRIX своя карточка
    return item === clockW ? 22 : item === photoW ? 12 : 18
  }
  // Порядок в общей колонке у одного якоря — как в NIHIL: часы, сеть, плеер, дальше остальное.
  readonly property var entries: [
    [clockW, "clockAnchor"], [netW, "networkAnchor"], [media, "mediaAnchor"], [sysW, "sysinfoAnchor"],
    [todoW, "todoAnchor"], [quoteW, "quoteAnchor"], [photoW, "photoAnchor"], [contribW, "contribAnchor"]
  ]
  // Позиция по якорю: top-left … bottom-right, center; отступ edgeMargin от бара / рамки до карточки.
  // Виджеты с одним якорем не налезают друг на друга, а встают колонкой (снизу — колонкой вверх).
  // "free" — центр из <name>Pos, в пределах экрана.
  function place(item, key) {
    if (dragKey === key) return dragPt
    return placeAt(item, key, String(host.value(key)))
  }
  // Позиция при якоре a (для DirectGrab — куда виджет прилипнет, вернувшись на место).
  function placeAt(item, key, a) {
    var p = padOf(item), w = item.width
    if (a === "free") {
      var pos = host.value(key.replace(/Anchor$/, "Pos")) || {}
      var cx = isFinite(Number(pos.cx)) ? Number(pos.cx) : 0.5
      var cy = isFinite(Number(pos.cy)) ? Number(pos.cy) : 0.5
      var fx = Math.max(p, Math.min(width - w - p, cx * width - w / 2))
      var fy = Math.max(p, Math.min(height - item.height - p, cy * height - item.height / 2))
      return Qt.point(Math.round(fx), Math.round(fy))
    }
    var m = host.num("edgeMargin")
    var gap = carded ? 14 : 24
    var group = entries.filter(function(e) { return e[0].visible && String(host.value(e[1])) === a })
    var total = 0, offset = 0
    for (var i = 0; i < group.length; i++) {
      var e = group[i][0], ext = e.height + 2 * padOf(e)
      if (e === item) offset = total + padOf(e)
      total += ext + (i < group.length - 1 ? gap : 0)
    }
    var x = a.indexOf("left") !== -1 ? mOf("left") + p : a.indexOf("right") !== -1 ? width - w - mOf("right") - p : (width - w) / 2
    var y = a.indexOf("top") !== -1 ? mOf("top") + offset
      : a.indexOf("bottom") !== -1 ? height - mOf("bottom") - total + offset
      : (height - total) / 2 + offset
    return Qt.point(Math.round(x), Math.round(y))
  }

  // ── Меню по ПКМ в режиме правки ──
  property string menuFor: ""
  function openMenu(name, x, y) {
    menuFor = name
    menu.x = Math.max(8, Math.min(width - menu.width - 8, x))
    menu.y = Math.max(8, Math.min(height - menu.height - 8, y))
  }
  function closeMenu() { menuFor = "" }

  Rectangle {
    id: menu
    visible: desk.host.editMode && desk.menuFor !== ""
    z: 100
    width: 260
    height: menuCol.implicitHeight + 12
    radius: 12
    color: desk.host.background
    border.width: 1
    border.color: Qt.rgba(desk.host.foreground.r, desk.host.foreground.g, desk.host.foreground.b, 0.2)

    readonly property bool free: desk.menuFor !== "" && desk.isFree(desk.menuFor)
    readonly property bool fl: desk.menuFor !== "" && desk.host.flag(desk.menuFor + "Float")
    readonly property var items: [
      { id: "float", icon: fl ? "󰐄" : "󰐃", text: fl ? desk.host.tr("Back under the windows", "Вернуть под окна")
                                                    : desk.host.tr("Keep above windows", "Поверх окон") },
      { id: "dock", icon: "󰁜", text: desk.host.tr("Back to its corner", "Вернуть на место"), off: !free },
      { id: "hide", icon: "󰈉", text: desk.host.tr("Hide widget", "Скрыть виджет") }
    ]

    Column {
      id: menuCol
      x: 6; y: 6
      width: parent.width - 12
      Repeater {
        model: menu.items
        delegate: Rectangle {
          required property var modelData
          visible: !modelData.off
          width: menuCol.width
          height: visible ? 36 : 0
          radius: 8
          color: rowMouse.containsMouse ? Qt.rgba(desk.host.accent.r, desk.host.accent.g, desk.host.accent.b, 0.18) : "transparent"
          Text {
            anchors.verticalCenter: parent.verticalCenter
            x: 12
            text: parent.modelData.icon + "   " + parent.modelData.text
            font.family: desk.host.fontFamily
            font.pixelSize: 14
            color: desk.host.foreground
          }
          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
              // Всё нужное — до closeMenu: смена menuFor пересобирает items, Repeater пересоздаёт строки,
              // и этот делегат (вместе с parent.modelData) пропадает посреди обработчика.
              var n = desk.menuFor, act = parent.modelData.id, wasFloat = menu.fl
              if (act === "float") desk.host.setFloat(n, !wasFloat, desk.screenName)
              else if (act === "dock") desk.host.dock(n)
              else if (act === "hide") desk.host.saveKeys(({ [n]: false }))
              desk.closeMenu()
            }
          }
        }
      }
    }
  }
}

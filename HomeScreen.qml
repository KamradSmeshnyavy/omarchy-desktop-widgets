import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "dotmatrix" as DotMatrix

// Домашний экран (по мотивам glyph-rice): на слое Bottom, только пока на активном столе этого
// монитора нет окон. Точечная сетка, крупные часы, приветствие по времени суток, дата и сетка 3×3
// плиток (плеер, погода, CPU, RAM, батарея, температура, сеть, прогресс дня, день года).
// Раскладка — homeLayout: classic (HomeClassic.qml) · glyph (HomeGlyph.qml, как в glyph-rice) · minimal.
// Ключи widgets.json: home (выкл. по умолчанию), homeLayout, homeName (имя в приветствии; пусто — $USER),
// homeDots (точечная сетка), homeHideWidgets (прятать виджеты на якорях, пока виден дом), homeScale,
// homeGreeting / homeDate / homeMeta (что показывать), homeBlink (мигающее двоеточие), homeCards
// (glyph: плоские карточки glyph или материал стиля), homeWidgets (glyph: плитки бенто через запятую).
PanelWindow {
  id: home

  required property var host            // Widgets.qml
  required property var modelData       // экран

  readonly property var monitor: Hyprland.monitorFor(modelData)
  readonly property int wsId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
  // Окна на активном столе этого монитора (спецстолы вроде scratchpad не в счёт).
  readonly property int windowCount: {
    var list = Hyprland.toplevels.values, n = 0
    for (var i = 0; i < list.length; i++) if (list[i].workspace && list[i].workspace.id === wsId) n++
    return n
  }
  readonly property bool shown: wsId > 0 && windowCount === 0
  onShownChanged: host.setHomeShown(String(modelData.name), shown)

  screen: modelData
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Normal
  color: "transparent"
  surfaceFormat.opaque: false
  visible: shown || fade.opacity > 0.01
  WlrLayershell.namespace: "omarchy-home"
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  // Клики — только по зоне плиток раскладки (layoutLoader.item.hit), остальное прозрачно для стола.
  mask: Region { item: home.shown && layoutLoader.item && layoutLoader.item.hit ? layoutLoader.item.hit : null }

  // Окно открыли / закрыли / перенесли — toplevels обновляются по событиям, но workspace у
  // окна приходит чуть позже: короткий пересчёт после событий окон.
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (/^(openwindow|closewindow|movewindow|movewindowv2|workspace|workspacev2|focusedmon)$/.test(event.name)) refresh.restart()
    }
  }
  Timer { id: refresh; interval: 150; onTriggered: Hyprland.refreshToplevels() }

  readonly property bool dot: host.dotmatrixWidgets
  readonly property color fg: dot ? DotMatrix.Palette.fg : host.foreground
  readonly property color dim: dot ? DotMatrix.Palette.dim : Qt.rgba(host.foreground.r, host.foreground.g, host.foreground.b, 0.62)

  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: home.visible; triggeredOnStart: true; onTriggered: home.now = new Date() }

  readonly property string userName: {
    var n = String(host.value("homeName") || "").trim()
    if (n !== "") return n
    var u = String(Quickshell.env("USER") || "")
    return u.length > 0 ? u.charAt(0).toUpperCase() + u.slice(1) : ""
  }
  readonly property string hello: {
    var h = now.getHours()
    return h < 5 ? host.tr("Good night", "Доброй ночи") : h < 12 ? host.tr("Good morning", "Доброе утро")
      : h < 18 ? host.tr("Good afternoon", "Добрый день") : host.tr("Good evening", "Добрый вечер")
  }
  readonly property string greeting: userName !== "" ? hello + ", " + userName : hello

  function rate(b) {
    return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB/s" : b >= 1024 ? Math.round(b / 1024) + " KB/s" : Math.round(b) + " B/s"
  }

  Item {
    id: fade
    anchors.fill: parent
    opacity: home.shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: home.host.deskStyle.ms(320); easing.type: Easing.OutCubic } }

    // Точечная сетка: рисуется один раз на размер окна.
    Canvas {
      id: dots
      anchors.fill: parent
      visible: home.host.value("homeDots") !== false
      opacity: 0.16
      onWidthChanged: requestPaint()
      onHeightChanged: requestPaint()
      property color c: home.fg
      onCChanged: requestPaint()
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.fillStyle = c
        var step = 22
        for (var y = step / 2; y < height; y += step)
          for (var x = step / 2; x < width; x += step) ctx.fillRect(Math.round(x), Math.round(y), 2, 2)
      }
    }

    Loader {
      id: layoutLoader
      anchors.fill: parent
      readonly property string layout: String(home.host.value("homeLayout") || "classic")
      sourceComponent: layout === "glyph" ? glyphL : layout === "minimal" ? minimalL : classicL
    }
    Component { id: classicL; HomeClassic { host: home.host; homeScreen: home } }
    Component { id: glyphL; HomeGlyph { host: home.host; homeScreen: home } }
    Component { id: minimalL; HomeMinimal { host: home.host; homeScreen: home } }
  }
}

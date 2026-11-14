import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// Дашборд у верхнего края (идея caelestia, написано с нуля). Вид — BarStyle (host.panelStyle):
//   attached — «вытекает» из-под сплошного бара / рамки: вогнутые углы сверху переходят в полосу;
//   floating — отдельная скруглённая карточка с отступом, рамкой и тенью (прозрачный или
//              «островной» бар — тогда затёкам не к чему прилипать).
// Анимация (dashAnimation): grow — растёт по высоте, slide — выезжает сверху, fade — проявляется,
// liquid — «вытекает» из бара: узкая капля растягивается в ширину и высоту с пружинным перелётом (Vitreus).
// Блоки включаются ключами dashMedia / dashCalendar / dashWeather / dashStats. Esc или клик мимо — закрыть.
PanelWindow {
  id: dash

  required property var host
  readonly property var style: host.panelStyle
  readonly property bool attached: style.attached

  // Блоки и ширина: колонка справа (погода + графики) — один блок, если есть хоть одно из двух.
  readonly property bool showMedia: host.value("dashMedia") !== false
  readonly property bool showCalendar: host.value("dashCalendar") !== false
  readonly property bool showWeather: host.value("dashWeather") !== false
  readonly property bool showStats: host.value("dashStats") !== false
  readonly property bool showSide: showWeather || showStats
  readonly property int pad: 20
  readonly property int gap: 16
  readonly property int contentWidth: {
    var w = [], n = 0
    if (showMedia) w.push(360)
    if (showCalendar) w.push(250)
    if (showSide) w.push(238)
    for (var i = 0; i < w.length; i++) n += w[i]
    return Math.max(250, n + Math.max(0, w.length - 1) * gap)
  }
  readonly property int bodyWidth: contentWidth + 2 * pad
  readonly property int bodyHeight: 300
  readonly property int flare: attached ? style.flare : 0
  readonly property int margin: attached ? 0 : 10       // отступ плавающей карточки от бара
  readonly property int shadowPad: attached ? 0 : 24
  readonly property string animation: String(host.value("dashAnimation"))
  readonly property int duration: Math.max(60, host.num("dashDuration"))

  property real progress: !host.dotmatrixDash && host.dashboardOpen ? 1 : 0
  readonly property bool liquid: animation === "liquid"
  // liquid открывается с перелётом (OutBack), закрывается без него — иначе капля «проваливается» в бар.
  Behavior on progress {
    NumberAnimation {
      duration: dash.liquid ? Math.round(dash.duration * 1.25) : dash.duration
      easing.type: dash.liquid && dash.host.dashboardOpen ? Easing.OutBack : Easing.OutCubic
      easing.overshoot: 1.3
    }
  }
  // grow — высота растёт; slide — сдвиг сверху; fade — только прозрачность (+ лёгкий масштаб);
  // liquid — высота догоняет ширину: сначала капля под баром, потом лист.
  // liquid (Vitreus): окно — вся полоса сверху поверх бара (Ignore), панель начинается прямо на пилюле бара
  // (BarGeom) и растягивается в карточку: ширина ведёт, высота догоняет, скругление — от пилюли к карточке.
  BarGeom { id: geo }
  onVisibleChanged: if (visible) geo.refresh()
  Connections {
    target: dash.host
    function onDashboardOpenChanged() {
      if (dash.host.dashboardOpen) { geo.refresh(); wave.stop() }
      else if (dash.fromBar) waveDelay.restart()
    }
  }
  // Волна: панель втянулась — по пилюле бара расходятся два световых кольца (у Vitreus бар качается).
  Timer { id: waveDelay; interval: Math.round(dash.duration * 0.7); onTriggered: if (!dash.host.dashboardOpen) wave.restart() }
  property real wv: 0
  NumberAnimation { id: wave; target: dash; property: "wv"; from: 0; to: 1; duration: 620; easing.type: Easing.OutCubic }
  // Бар у любого края: панель встаёт рядом с ним (сверху / снизу — по центру, слева / справа — по середине высоты),
  // перешеек выходит из внутренней кромки пилюли. Окно — весь экран (Ignore), клики — только по панели (mask).
  readonly property bool fromBar: liquid && geo.barLayer.width > 0
  readonly property string edge: geo.edge
  readonly property bool sideBar: edge === "left" || edge === "right"
  readonly property real scrW: screen ? screen.width : width
  readonly property real scrH: screen ? screen.height : height
  readonly property real m: Math.max(0, progress)
  readonly property real mw: Math.min(1.03, m * 1.35)
  readonly property real mh: Math.pow(Math.min(1.04, m), 1.35)
  // кусок пилюли напротив панели, откуда она начинается
  readonly property rect startRect: !sideBar
    ? Qt.rect((scrW - Math.min(geo.pill.width, 240)) / 2, geo.pill.y, Math.min(geo.pill.width, 240), geo.pill.height)
    : Qt.rect(geo.pill.x, (scrH - Math.min(geo.pill.height, 240)) / 2, geo.pill.width, Math.min(geo.pill.height, 240))
  readonly property rect endRect: edge === "top" ? Qt.rect((scrW - bodyWidth) / 2, geo.pill.y + geo.pill.height + 10, bodyWidth, bodyHeight)
    : edge === "bottom" ? Qt.rect((scrW - bodyWidth) / 2, geo.pill.y - 10 - bodyHeight, bodyWidth, bodyHeight)
    : edge === "left" ? Qt.rect(geo.pill.x + geo.pill.width + 10, (scrH - bodyHeight) / 2, bodyWidth, bodyHeight)
    : Qt.rect(geo.pill.x - 10 - bodyWidth, (scrH - bodyHeight) / 2, bodyWidth, bodyHeight)
  // вдоль бара растёт быстрее (mw), от бара — догоняет (mh)
  readonly property real mAlongX: sideBar ? mh : mw
  readonly property real mAlongY: sideBar ? mw : mh
  readonly property rect morph: Qt.rect(startRect.x + (endRect.x - startRect.x) * Math.min(1, mAlongX), startRect.y + (endRect.y - startRect.y) * Math.min(1, mAlongY),
                                        startRect.width + (endRect.width - startRect.width) * mAlongX, startRect.height + (endRect.height - startRect.height) * mAlongY)
  // опора перешейка: тонкая полоска у внутренней кромки пилюли
  readonly property rect neckBase: edge === "top" ? Qt.rect(scrW / 2 - 70, geo.pill.y + geo.pill.height - 5, 140, 5)
    : edge === "bottom" ? Qt.rect(scrW / 2 - 70, geo.pill.y, 140, 5)
    : edge === "left" ? Qt.rect(geo.pill.x + geo.pill.width - 5, scrH / 2 - 70, 5, 140)
    : Qt.rect(geo.pill.x, scrH / 2 - 70, 5, 140)
  // скругление панели — не пилюля, даже если бар полностью круглый (glyph-pill: radius 99)
  readonly property real panelRadius: Math.min(style.cornerRadius, 28)
  readonly property real morphRadius: geo.radius + (panelRadius - geo.radius) * Math.min(1, m * 2)
  readonly property real h: animation === "grow" ? Math.round(bodyHeight * progress)
    : liquid ? Math.round(bodyHeight * Math.max(0, Math.min(1.04, progress * progress))) : bodyHeight
  readonly property real w: liquid ? Math.round(bodyWidth * Math.max(0.18, Math.min(1.02, 0.18 + 0.82 * Math.sqrt(Math.max(0, progress))))) : bodyWidth
  readonly property real slide: animation === "slide" ? (1 - progress) * -(bodyHeight + margin) : 0
  readonly property real fadeOpacity: animation === "grow" || liquid ? Math.min(1, progress * 3) : progress

  visible: !host.dotmatrixDash && (progress > 0.001 || wave.running)
  screen: host.focusedScreen
  anchors.top: true
  anchors.left: fromBar
  anchors.right: fromBar
  anchors.bottom: fromBar
  exclusionMode: fromBar ? ExclusionMode.Ignore : ExclusionMode.Normal
  exclusiveZone: 0
  implicitWidth: bodyWidth + 2 * Math.max(flare, shadowPad)
  implicitHeight: bodyHeight + margin + shadowPad
  color: "transparent"
  surfaceFormat.opaque: false
  WlrLayershell.namespace: "omarchy-dashboard"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: !host.dotmatrixDash && host.dashboardOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  mask: Region { item: dash.cardDrag || dash.pulling ? null : hit; regions: dash.cardDrag || dash.pulling ? [dragAll] : [] }
  Region { id: dragAll; x: 0; y: 0; width: dash.width; height: dash.height }
  // Плеер берут мышью и вытягивают из дашборда (как у Vitreus): отпустил за его краем — плеер остаётся на столе
  // поверх окон в этой точке, внутри — возвращается на место. Пока тянут, окно — до низа экрана (fromBar).
  property bool cardDrag: false
  // Отрыв от бара (как Desk у Vitreus): тянут за верхнюю полосу — перешеек тянется и рвётся, панель остаётся там, где
  // отпустили (detached: не закрывается кликом мимо, Esc — закрыть); отпустили у бара — прилипает обратно.
  property bool detached: false
  property bool pulling: false
  property point freePos: Qt.point(0, 0)
  property point pullBase: Qt.point(0, 0)
  property bool snapping: false
  readonly property bool loose: fromBar && (detached || pulling)
  readonly property real pullDist: loose ? Math.hypot(freePos.x - endRect.x, freePos.y - endRect.y) : 0
  // перешеек: держится, пока панель рядом, тянется и рвётся у 170 px
  readonly property real neckK: !fromBar ? 0 : !loose ? 26 : pulling && pullDist < 170 ? 26 + pullDist * 0.35 : 0

  HyprlandFocusGrab {
    active: !dash.host.dotmatrixDash && dash.host.dashboardOpen && !dash.detached
    windows: [dash]
    onCleared: dash.host.dashboardOpen = false
  }

  Repeater {
    model: dash.fromBar && wave.running ? 2 : 0
    Rectangle {
      required property int index
      readonly property real k: Math.max(0, Math.min(1, dash.wv * 1.25 - index * 0.25))
      readonly property real ax: dash.sideBar ? 4 : 18
      readonly property real ay: dash.sideBar ? 18 : 4
      x: dash.startRect.x - ax * k * (index + 1)
      y: dash.startRect.y - ay * k * (index + 1)
      width: dash.startRect.width + 2 * ax * k * (index + 1)
      height: dash.startRect.height + 2 * ay * k * (index + 1)
      radius: height / 2
      color: "transparent"
      border.width: 1.5
      border.color: Qt.rgba(1, 1, 1, 0.55 * (1 - k))
    }
  }

  // Всё содержимое — в «листе», который сдвигается при slide.
  Item {
    id: sheet
    width: dash.width
    height: dash.height
    y: dash.slide
    opacity: dash.fadeOpacity
    scale: dash.animation === "fade" ? 0.97 + 0.03 * dash.progress : 1
    transformOrigin: Item.Top

    Item {
      id: hit
      x: dash.loose ? dash.freePos.x : dash.fromBar ? dash.morph.x : (dash.width - dash.w) / 2
      y: dash.loose ? dash.freePos.y : dash.fromBar ? dash.morph.y : dash.margin
      width: dash.loose ? dash.bodyWidth : dash.fromBar ? dash.morph.width : dash.w
      height: dash.loose ? dash.bodyHeight : dash.fromBar ? dash.morph.height : dash.h
      Behavior on x { enabled: dash.snapping; NumberAnimation { duration: 320; easing.type: Easing.OutBack } }
      Behavior on y { enabled: dash.snapping; NumberAnimation { duration: 320; easing.type: Easing.OutBack } }

      // верхняя полоса — за неё отрывают (кнопки ниже неё)
      Item {
        id: grip
        visible: dash.fromBar && dash.host.dashboardOpen
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 18
        z: 20
        HoverHandler { cursorShape: gripDrag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor }
        Rectangle {
          anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 6 }
          width: 44; height: 4; radius: 2
          color: Qt.rgba(dash.host.foreground.r, dash.host.foreground.g, dash.host.foreground.b, gripDrag.active ? 0.6 : 0.28)
        }
        DragHandler {
          id: gripDrag
          target: null
          dragThreshold: 4
          onActiveChanged: {
            if (active) {
              dash.pullBase = Qt.point(hit.x, hit.y)
              dash.freePos = dash.pullBase
              dash.pulling = true
              return
            }
            var home = Math.hypot(dash.freePos.x - dash.endRect.x, dash.freePos.y - dash.endRect.y) < 80
            dash.pulling = false
            if (home) { dash.snapping = true; dash.detached = false; snapOff.restart() }
            else dash.detached = true
          }
          onTranslationChanged: if (active) {
            var sw = dash.screen ? dash.screen.width : dash.width, sh = dash.screen ? dash.screen.height : 900
            dash.freePos = Qt.point(Math.max(0, Math.min(sw - dash.bodyWidth, dash.pullBase.x + translation.x)),
                                    Math.max(0, Math.min(sh - dash.bodyHeight, dash.pullBase.y + translation.y)))
          }
        }
      }
    }
    Timer { id: snapOff; interval: 360; onTriggered: dash.snapping = false }

    // attached: контур с вогнутыми углами сверху.
    Shape {
      visible: dash.attached
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        id: outline
        // Пока дашборд ниже радиуса, вогнутый угол сплющен по высоте (эллипс), а нижние
        // углы берут только оставшуюся высоту — контур не ломается при любой высоте.
        readonly property real fy: Math.min(dash.flare, dash.h)
        readonly property real br: Math.max(0, Math.min(dash.style.cornerRadius, (dash.h - fy) / 2))
        readonly property real left: hit.x
        readonly property real right: hit.x + hit.width

        fillColor: dash.style.color
        strokeWidth: -1
        startX: outline.left - dash.flare
        startY: 0

        PathLine { x: outline.right + dash.flare; y: 0 }
        PathArc { x: outline.right; y: outline.fy; radiusX: Math.max(0.01, dash.flare); radiusY: Math.max(0.01, outline.fy); direction: PathArc.Counterclockwise }
        PathLine { x: outline.right; y: dash.h - outline.br }
        PathArc { x: outline.right - outline.br; y: dash.h; radiusX: Math.max(0.01, outline.br); radiusY: Math.max(0.01, outline.br) }
        PathLine { x: outline.left + outline.br; y: dash.h }
        PathArc { x: outline.left; y: dash.h - outline.br; radiusX: Math.max(0.01, outline.br); radiusY: Math.max(0.01, outline.br) }
        PathLine { x: outline.left; y: outline.fy }
        PathArc { x: outline.left - dash.flare; y: 0; radiusX: Math.max(0.01, dash.flare); radiusY: Math.max(0.01, outline.fy); direction: PathArc.Counterclockwise }
      }
    }

    // floating: карточка с рамкой и тенью.
    // Материал стиля (бумага, неоморфизм, брутализм, кант, неон) — StyleCard вместо карточки.
    StyleCard {
      visible: !dash.attached && dash.style.card
      style: dash.style
      seed: 3
      glassLayer: "omarchy-dashboard"
      glassOrigin: dash.fromBar ? Qt.point(hit.x, hit.y) : Qt.point(NaN, NaN)
      // перешеек к пилюле бара: панель стекает из бара одним куском стекла (Vitreus)
      glassBleed: dash.fromBar && dash.neckK > 0 ? Math.max(Math.max(dash.neckBase.x - hit.x - hit.width, hit.x - dash.neckBase.x - dash.neckBase.width),
                                                             Math.max(dash.neckBase.y - hit.y - hit.height, hit.y - dash.neckBase.y - dash.neckBase.height), 0) + 40 : 0
      // опора — тонкая полоска у нижней кромки пилюли: перешеек выходит из края бара, не закрывая его содержимое
      glassJoin: dash.fromBar && dash.neckK > 0 ? Qt.rect(dash.neckBase.x - hit.x, dash.neckBase.y - hit.y, dash.neckBase.width, dash.neckBase.height) : Qt.rect(0, 0, 0, 0)
      glassJoinRadius: 2.5
      glassJoinK: dash.neckK
      x: hit.x
      y: hit.y
      width: hit.width
      height: hit.height
      radius: dash.fromBar ? Math.min(dash.morphRadius, height / 2) : Math.min(dash.style.cornerRadius, height / 2)
    }
    Rectangle {
      visible: !dash.attached && !dash.style.card
      x: hit.x
      y: hit.y
      width: hit.width
      height: hit.height
      radius: Math.min(dash.style.cornerRadius, height / 2)
      color: dash.style.color
      border.width: dash.style.borderWidth
      border.color: dash.style.borderColor
      layer.enabled: dash.style.shadowOn
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: dash.style.shadowOpacity
        shadowBlur: dash.style.shadowBlur
        shadowVerticalOffset: 4 * dash.style.lift
      }
    }

    Item {
      id: content
      x: dash.loose ? hit.x : dash.fromBar ? dash.endRect.x : (dash.width - dash.bodyWidth) / 2
      y: dash.loose ? hit.y : dash.fromBar ? dash.endRect.y + (dash.edge === "top" ? 14 : dash.edge === "bottom" ? -14 : 0) * (1 - Math.min(1, dash.m)) : hit.y
      width: dash.bodyWidth
      height: dash.fromBar ? dash.bodyHeight : dash.h
      clip: !dash.fromBar
      opacity: dash.animation === "grow" || dash.liquid ? Math.max(0, (Math.min(1, dash.progress) - (dash.liquid ? 0.55 : 0.35)) / (dash.liquid ? 0.45 : 0.65)) : 1
      focus: dash.host.dashboardOpen
      Keys.onEscapePressed: dash.host.dashboardOpen = false

      Row {
        x: dash.pad
        y: 16
        height: dash.bodyHeight - 36
        spacing: dash.gap

        DashMedia {
          id: dm
          visible: dash.showMedia; host: dash.host; width: 360; height: parent.height
          z: dash.cardDrag ? 10 : 0
          transform: Translate { id: dmT }
          DragHandler {
            id: dmDrag
            target: null
            enabled: dash.fromBar
            dragThreshold: 10
            onActiveChanged: {
              if (active) { dash.cardDrag = true; return }
              var c = dm.mapToItem(null, dm.width / 2 + 0, dm.height / 2 + 0)
              var out = c.y > hit.y + hit.height + 30 || c.y < hit.y - 30 || c.x < hit.x - 30 || c.x > hit.x + hit.width + 30
              if (out && dash.screen) dash.host.detachAt("media", String(dash.screen.name), c.x / dash.screen.width, c.y / dash.screen.height)
              back.restart()
              dash.cardDrag = false
            }
            onTranslationChanged: if (active) { dmT.x = translation.x; dmT.y = translation.y }
          }
          ParallelAnimation {
            id: back
            NumberAnimation { target: dmT; property: "x"; to: 0; duration: 260; easing.type: Easing.OutBack }
            NumberAnimation { target: dmT; property: "y"; to: 0; duration: 260; easing.type: Easing.OutBack }
          }
        }
        DashCalendar { visible: dash.showCalendar; host: dash.host; width: 250; height: parent.height }
        Column {
          visible: dash.showSide
          width: 238
          height: parent.height
          spacing: 12
          DashWeather { visible: dash.showWeather; host: dash.host; width: parent.width; height: dash.showStats ? 116 : parent.height }
          DashStats { visible: dash.showStats; host: dash.host; width: parent.width; height: dash.showWeather ? parent.height - 128 : parent.height }
        }
      }
    }
  }
}

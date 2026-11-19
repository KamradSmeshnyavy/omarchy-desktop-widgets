import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import "menus" as Menus

// «Остров» Modern — пилюля бара вырастает в карточку (по мотивам стиля Modern из elifouts/Dotfiles, GPL-3.0 — его
// quickshell/Modern/bar/Pill.qml: карточка растёт из пилюли вширь и вниз, страницы сменяют друг друга со сдвигом;
// код свой). Пилюлю рисует бар (kamradsmeshnyavy.bar ModernModule) и сообщает её место (IPC widgets modernIsland);
// остров рисует поверх неё одно стекло — пилюля + карточка, фон темы на 60 % с тонкой окантовкой, а свой фон пилюля
// прячет, пока остров открыт ($XDG_RUNTIME_DIR/omarchy-modern-island). Страницы: workspaces (столы и окна), island
// (сейчас играет), calendar, network / bt / audio (общие разделы меню — SectionBody), power (сеанс), updates,
// notifications; control — Super+M у райса Modern (settingsPanel modern): вкладки Wi-Fi / Bluetooth / звук / сеанс.
// Открытые наведением закрываются, когда мышь уходит; открытые кликом и Super+M — кликом мимо или Esc.
PanelWindow {
  id: isl
  required property var host

  // ── что открыто ──
  property string page: ""
  property bool hoverMode: false
  property rect pill: Qt.rect(0, 0, 0, 0)   // место пилюли в окне бара
  property string align: "center"
  readonly property bool superM: host.settingsOpen && String(host.value("settingsPanel")) === "modern"
  readonly property string shown: superM ? "control" : page
  readonly property bool open: shown !== ""
  onSuperMChanged: if (superM) { page = ""; geo.refresh(); controlTab = "wifi" }

  function show(p, x, y, w, h, al, hover) {
    geo.refresh()
    pill = Qt.rect(x, y, w, h)
    align = al
    hoverMode = hover
    page = p
    everHovered = false
    leaveTimer.restart()
  }
  function close() { page = ""; if (superM) host.settingsOpen = false }

  // ── геометрия: окно бара на экране (BarGeom) + место пилюли в нём ──
  BarGeom { id: geo }
  readonly property real px: superM ? (width - 300) / 2 : geo.barLayer.x + pill.x
  // Super+M: остров под баром (своя «пилюля» — вкладки), чтобы не лечь на пилюли бара
  readonly property real py: superM ? geo.barLayer.y + geo.barLayer.height + 6 : geo.barLayer.y + pill.y
  readonly property real pw: superM ? 300 : pill.width
  readonly property real ph: superM ? 34 : pill.height
  readonly property var widths: ({ workspaces: 600, island: 520, calendar: 380, network: 420, bt: 420, audio: 400, power: 360,
    updates: 320, notifications: 340, control: 460 })

  // ── вид ──
  readonly property color fg: host.foreground
  readonly property color bg: host.background
  readonly property color accent: host.accent
  function a(c, k) { return Qt.rgba(c.r, c.g, c.b, k) }
  readonly property string font: Qt.fontFamilies().indexOf("CodeNewRoman Nerd Font Propo") !== -1 ? "CodeNewRoman Nerd Font Propo"
    : Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : "monospace"

  property real t: open ? 1 : 0
  Behavior on t { NumberAnimation { duration: 280; easing.type: Easing.BezierSpline; easing.bezierCurve: isl.open ? [0.15, 0.85, 0.25, 1, 1, 1] : [0.3, 1, 0.4, 1, 1, 1] } }
  property string drawn: ""
  onShownChanged: if (shown !== "") drawn = shown
  onTChanged: if (t === 0 && !open) drawn = ""

  screen: host.focusedScreen
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  visible: t > 0.001
  WlrLayershell.namespace: "omarchy-modern-island"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: open && !hoverMode ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  mask: Region { item: hoverMode ? card : full }
  Item { id: full; anchors.fill: parent }

  // пилюля прячет свой фон, пока остров её накрывает
  FileView { id: cover; path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarchy-modern-island"; printErrors: false }
  onOpenChanged: cover.setText("")

  MouseArea { anchors.fill: parent; enabled: !isl.hoverMode; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: isl.close() }

  // наведение: закрыть, когда мышь ушла (его closeDelay 90 мс; если так и не зашла — через 1,2 с)
  property bool everHovered: false
  Timer { id: leaveTimer; interval: isl.everHovered ? 220 : 1200; onTriggered: if (isl.hoverMode && !cardHover.hovered) isl.page = "" }

  MenuData { id: md; live: isl.open && ["network", "bt", "audio", "control"].indexOf(isl.shown) !== -1 }
  property string controlTab: "wifi"

  Item {
    id: card
    readonly property real bodyW: Math.max(isl.pw, isl.widths[isl.drawn] ?? 360)
    readonly property real w: isl.pw + (bodyW - isl.pw) * isl.t
    readonly property real bodyH: body.item ? body.item.implicitHeight + 28 : 0
    x: isl.align === "left" && !isl.superM ? isl.px : isl.align === "right" && !isl.superM ? isl.px + isl.pw - w : isl.px + isl.pw / 2 - w / 2
    y: isl.py
    width: w
    height: isl.ph + bodyH * isl.t
    HoverHandler { id: cardHover; onHoveredChanged: { if (hovered) { isl.everHovered = true; leaveTimer.stop() } else if (isl.hoverMode) leaveTimer.restart() } }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onWheel: function(w) { w.accepted = false } }

    // стекло: фон темы на 60 % с окантовкой; на месте пилюли — дырка по её форме (там её собственное стекло и текст)
    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        fillRule: ShapePath.OddEvenFill
        fillColor: isl.a(isl.bg, 0.6)
        strokeWidth: 1
        strokeColor: Qt.tint(isl.a(isl.bg, 0.6), isl.a(isl.fg, 0.14))
        PathRectangle { x: 0.5; y: 0.5; width: card.width - 1; height: card.height - 1; radius: 12 }
        PathRectangle {
          x: isl.superM ? -1 : isl.px - card.x
          y: isl.superM ? -1 : 0
          width: isl.superM ? 0 : isl.pw
          height: isl.superM ? 0 : isl.ph
          radius: Math.min(10, isl.ph / 2)
        }
      }
    }
    // Super+M: своей пилюли нет — стекло сплошное
    Rectangle { visible: false }
    // Super+M: заголовок в «пилюле»
    Row {
      visible: isl.superM
      anchors.horizontalCenter: parent.horizontalCenter
      height: isl.ph
      spacing: 4
      Repeater {
        model: [["wifi", "󰤨", "Wi-Fi"], ["bt", "󰂯", "Bluetooth"], ["audio", "󰕾", "Sound"], ["power", "⏻", "Session"]]
        Rectangle {
          required property var modelData
          readonly property bool on: isl.controlTab === modelData[0]
          anchors.verticalCenter: parent.verticalCenter
          width: tl.implicitWidth + 20; height: isl.ph - 8; radius: height / 2
          color: on ? isl.a(isl.accent, 0.3) : ta.containsMouse ? isl.a(isl.fg, 0.08) : "transparent"
          Text { id: tl; anchors.centerIn: parent; text: parent.modelData[1] + "  " + parent.modelData[2]; font.family: isl.font; font.pixelSize: 12; color: parent.on ? isl.fg : isl.a(isl.fg, 0.7) }
          MouseArea { id: ta; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: isl.controlTab = parent.modelData[0] }
        }
      }
    }
    Item {
      y: isl.ph
      width: parent.width
      height: parent.height - isl.ph
      clip: true
      Loader {
        id: body
        x: 14; y: 8
        width: card.bodyW - 28
        opacity: Math.max(0, isl.t * 2 - 1)
        transform: Translate { y: (1 - isl.t) * 8 }
        active: isl.drawn !== ""
        sourceComponent: ({ workspaces: wsC, island: mediaC, calendar: calC, network: secC, bt: secC, audio: secC, power: powerC,
          updates: updC, notifications: notifC, control: controlC })[isl.drawn] ?? null
      }
    }
  }

  component Txt: Text { font.family: isl.font; font.pixelSize: 12; color: isl.fg; elide: Text.ElideRight }
  component Btn: Rectangle {
    id: bb
    property string glyph: ""
    property string label: ""
    property bool lit: false
    signal hit()
    width: Math.max(44, bl.implicitWidth + 24); height: 40; radius: 10
    color: lit ? isl.accent : ba.containsMouse ? isl.a(isl.fg, 0.12) : isl.a(isl.fg, 0.06)
    Text { id: bl; anchors.centerIn: parent; text: bb.glyph + (bb.label ? "  " + bb.label : ""); font.family: isl.font; font.pixelSize: 13; color: bb.lit ? isl.bg : isl.fg }
    MouseArea { id: ba; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bb.hit() }
  }

  // ── страницы ──
  Component {
    id: secC
    Menus.SectionBody {
      implicitHeight: 300
      md: md
      page: isl.drawn === "network" ? "wifi" : isl.drawn
      ink: isl.fg; litFill: isl.a(isl.accent, 0.3); litInk: isl.fg; hoverFill: isl.a(isl.fg, 0.08); line: isl.a(isl.fg, 0.14)
      radius: 10; size: 12; rowH: 36; field: isl.a(isl.fg, 0.06); font: isl.font
    }
  }
  Component {
    id: controlC
    Item {
      implicitHeight: 320
      Menus.SectionBody {
        visible: isl.controlTab !== "power"
        anchors.fill: parent
        md: md
        page: isl.controlTab === "power" ? "" : isl.controlTab
        ink: isl.fg; litFill: isl.a(isl.accent, 0.3); litInk: isl.fg; hoverFill: isl.a(isl.fg, 0.08); line: isl.a(isl.fg, 0.14)
        radius: 10; size: 12; rowH: 36; field: isl.a(isl.fg, 0.06); font: isl.font
      }
      Loader { visible: isl.controlTab === "power"; anchors.horizontalCenter: parent.horizontalCenter; y: 20; sourceComponent: powerC }
    }
  }
  Component {
    id: powerC
    Row {
      spacing: 8
      Repeater {
        model: [["󰌾", "Lock", ["omarchy-lock-screen"]], ["󰍃", "Logout", ["omarchy-system", "logout"]], ["󰤄", "Sleep", ["systemctl", "suspend"]],
          ["󰜉", "Reboot", ["omarchy-system", "reboot"]], ["⏻", "Off", ["omarchy-system", "shutdown"]]]
        Btn { required property var modelData; glyph: modelData[0]; onHit: { isl.close(); Quickshell.execDetached(modelData[2]) } }
      }
    }
  }
  Component {
    id: mediaC
    Item {
      readonly property var p: isl.host.player
      implicitHeight: 128
      Rectangle {
        id: art
        width: 96; height: 96; y: 4; radius: 10
        color: isl.a(isl.fg, 0.08)
        clip: true
        Image { anchors.fill: parent; source: parent.parent.p && parent.parent.p.trackArtUrl ? parent.parent.p.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 192 }
      }
      Column {
        x: art.width + 16; y: 8
        width: parent.width - x
        spacing: 4
        Txt { width: parent.width; text: parent.parent.p ? (parent.parent.p.trackTitle || "") : "Nothing playing"; font.pixelSize: 15; color: isl.fg }
        Txt { width: parent.width; text: parent.parent.p ? (parent.parent.p.trackArtist || "") : Qt.formatDate(new Date(), "dddd, d MMMM"); color: isl.a(isl.fg, 0.6) }
        Item { width: 1; height: 8 }
        Rectangle {
          width: parent.width; height: 4; radius: 2; color: isl.a(isl.fg, 0.12)
          Rectangle { height: parent.height; radius: 2; color: isl.accent; width: parent.parent.parent.p && parent.parent.parent.p.length > 0 ? parent.width * Math.min(1, parent.parent.parent.p.position / parent.parent.parent.p.length) : 0 }
        }
        Row {
          spacing: 8
          Btn { glyph: "󰒮"; onHit: { var q = isl.host.player; if (q && q.canGoPrevious) q.previous() } }
          Btn { glyph: isl.host.player && isl.host.player.isPlaying ? "󰏤" : "󰐊"; lit: true; onHit: { var q = isl.host.player; if (q && q.canTogglePlaying) q.togglePlaying() } }
          Btn { glyph: "󰒭"; onHit: { var q = isl.host.player; if (q && q.canGoNext) q.next() } }
        }
      }
    }
  }
  Component {
    id: calC
    Column {
      id: cal
      spacing: 6
      property date d: new Date()
      readonly property int first: (new Date(d.getFullYear(), d.getMonth(), 1).getDay() + 6) % 7
      readonly property int days: new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate()
      Item {
        width: parent.width; height: 24
        Txt { text: Qt.formatDate(cal.d, "MMMM yyyy"); font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
        Row {
          anchors.right: parent.right; spacing: 6
          Txt { text: "‹"; font.pixelSize: 16; MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: cal.d = new Date(cal.d.getFullYear(), cal.d.getMonth() - 1, 1) } }
          Txt { text: "›"; font.pixelSize: 16; MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: cal.d = new Date(cal.d.getFullYear(), cal.d.getMonth() + 1, 1) } }
        }
      }
      Grid {
        columns: 7; spacing: 2
        Repeater { model: ["M", "T", "W", "T", "F", "S", "S"]; Txt { required property string modelData; width: (cal.width - 12) / 7; horizontalAlignment: Text.AlignHCenter; text: modelData; color: isl.a(isl.fg, 0.45); font.pixelSize: 10 } }
        Repeater {
          model: 42
          Rectangle {
            required property int index
            readonly property int day: index - cal.first + 1
            readonly property bool today: day === new Date().getDate() && cal.d.getMonth() === new Date().getMonth() && cal.d.getFullYear() === new Date().getFullYear()
            width: (cal.width - 12) / 7; height: 24; radius: 12
            color: today ? isl.accent : "transparent"
            Txt { anchors.centerIn: parent; text: parent.day >= 1 && parent.day <= cal.days ? String(parent.day) : ""; color: parent.today ? isl.bg : isl.fg }
          }
        }
      }
    }
  }
  Component {
    id: wsC
    Flow {
      spacing: 8
      Repeater {
        model: Hyprland.workspaces.values.filter(function(w) { return w.id > 0 }).sort(function(a, b) { return a.id - b.id })
        Rectangle {
          required property var modelData
          readonly property bool cur: !!Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData.id
          width: (isl.widths.workspaces - 28 - 16) / 3; height: 76; radius: 10
          color: wa.containsMouse ? isl.a(isl.fg, 0.1) : isl.a(isl.fg, 0.05)
          border.width: cur ? 1 : 0; border.color: isl.accent
          Txt { x: 10; y: 8; text: String(parent.modelData.id); font.pixelSize: 14; font.bold: true; color: parent.cur ? isl.accent : isl.fg }
          Column {
            x: 10; y: 30; width: parent.width - 20
            Repeater {
              model: parent.parent.modelData.toplevels ? parent.parent.modelData.toplevels.values.slice(0, 2) : []
              Txt { required property var modelData; width: parent.width; text: modelData.title || ""; color: isl.a(isl.fg, 0.6); font.pixelSize: 11 }
            }
          }
          MouseArea { id: wa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: { Quickshell.execDetached(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ workspace = " + parent.modelData.id + " }))"]); isl.close() } }
        }
      }
    }
  }
  Component {
    id: updC
    Column {
      spacing: 10
      Txt { text: "System updates"; font.pixelSize: 13 }
      Btn { glyph: "󰚰"; label: "Update"; onHit: { isl.close(); Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "omarchy-update"]) } }
    }
  }
  Component {
    id: notifC
    Column {
      spacing: 10
      Txt { text: "Notifications"; font.pixelSize: 13 }
      Row {
        spacing: 8
        Btn { glyph: "󰂚"; label: "History"; onHit: { isl.close(); Quickshell.execDetached(["omarchy-shell", "notifications", "showHistory"]) } }
        Btn { glyph: "󰂛"; label: "Do not disturb"; onHit: Quickshell.execDetached(["omarchy-shell", "notifications", "toggleDnd"]) }
      }
    }
  }

  FocusScope {
    anchors.fill: parent
    focus: isl.open && !isl.hoverMode
    Keys.onEscapePressed: isl.close()
  }
}

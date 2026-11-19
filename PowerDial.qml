import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Меню выключения «диск» (powerStyle "dial"; по мотивам радиального лаунчера Modern из elifouts/Dotfiles, GPL-3.0 —
// облик, код свой): по центру экрана круг стекла, в середине — часы и аптайм, по кольцу — пять действий (блокировка,
// сон, выход, перезагрузка, выключение). Дуга-указатель поворачивается к выбранному: мышь — по углу от центра, колесо и
// ←→ / Tab — по кругу. Безопасное (замок, сон) — клик / Enter; опасное — удержание: кольцо заполняется за 0,7 с,
// отпустил раньше — отмена. Esc и клик мимо — закрыть. Открывается host.powerOpen.
PanelWindow {
  id: root

  required property var host
  readonly property bool open: host.powerOpen && host.value("powerStyle") === "dial"
  readonly property color bg: host.background
  readonly property color fg: host.foreground
  readonly property color accent: host.accent
  function a(c, k) { return Qt.rgba(c.r, c.g, c.b, k) }
  readonly property string font: Qt.fontFamilies().indexOf("CodeNewRoman Nerd Font Propo") !== -1 ? "CodeNewRoman Nerd Font Propo"
    : Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : "monospace"

  readonly property var items: [
    { g: "\u{F033E}", l: "Lock", cmd: "omarchy-system-lock", hold: false },
    { g: "\u{F0904}", l: "Sleep", cmd: "systemctl suspend", hold: false },
    { g: "\u{F0343}", l: "Logout", cmd: "omarchy-system logout", hold: true },
    { g: "\u{F0709}", l: "Reboot", cmd: "omarchy-system reboot", hold: true },
    { g: "\u{F0425}", l: "Shutdown", cmd: "omarchy-system shutdown", hold: true }
  ]
  readonly property int n: items.length
  property int sel: 0
  property real fill: 0          // удержание 0..1
  property string uptime: ""
  property date now: new Date()
  property real k: open ? 1 : 0
  Behavior on k { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
  // угол выбранного (0 — сверху, по часовой), плавно и по короткой дуге
  property real ang: 0
  Behavior on ang { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
  onSelChanged: {
    const target = sel * 360 / n
    let d = ((target - ang) % 360 + 540) % 360 - 180
    ang = ang + d
  }

  Process { id: up; command: ["uptime", "-p"]; stdout: StdioCollector { onStreamFinished: root.uptime = String(text || "").trim().replace(/^up\s+/, "") } }
  Timer { interval: 1000; repeat: true; running: root.open; triggeredOnStart: true; onTriggered: root.now = new Date() }
  onOpenChanged: if (open) { sel = 0; ang = 0; fill = 0; up.running = true; keys.forceActiveFocus() } else { holding.stop(); fill = 0 }
  function close() { host.powerOpen = false }
  function run(i) { const c = items[i].cmd; close(); Quickshell.execDetached(["bash", "-c", c]) }
  function press(i) { sel = i; if (!items[i].hold) { run(i); return } holding.restart() }
  function release() { if (holding.running) { holding.stop(); unfill.restart() } }
  NumberAnimation { id: holding; target: root; property: "fill"; from: root.fill; to: 1; duration: 700 * (1 - root.fill); onFinished: if (root.fill >= 1) root.run(root.sel) }
  NumberAnimation { id: unfill; target: root; property: "fill"; to: 0; duration: 200 }

  screen: host.focusedScreen
  visible: open || k > 0.01
  anchors { left: true; right: true; top: true; bottom: true }
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  WlrLayershell.namespace: "omarchy-power"

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.45 * root.k)
    MouseArea { anchors.fill: parent; onClicked: root.close() }
  }

  Item {
    id: dial
    readonly property real size: Math.min(520, Math.min(root.width, root.height) * 0.6)
    readonly property real r: size / 2 - 52
    width: size; height: size
    anchors.centerIn: parent
    opacity: root.k
    scale: 0.9 + 0.1 * root.k

    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: root.a(root.bg, 0.82)
      border.width: 1
      border.color: root.a(root.fg, 0.08)
    }
    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      // кольцо дорожки
      ShapePath {
        strokeWidth: 2; strokeColor: root.a(root.fg, 0.08); fillColor: "transparent"
        PathAngleArc { centerX: dial.width / 2; centerY: dial.height / 2; radiusX: dial.r; radiusY: dial.r; startAngle: 0; sweepAngle: 360 }
      }
      // дуга-указатель на выбранном
      ShapePath {
        strokeWidth: 4; strokeColor: root.accent; fillColor: "transparent"; capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: dial.width / 2; centerY: dial.height / 2; radiusX: dial.r; radiusY: dial.r
          startAngle: root.ang - 90 - 360 / root.n / 2 + 6; sweepAngle: 360 / root.n - 12 }
      }
      // удержание: кольцо заполняется
      ShapePath {
        strokeWidth: 6; strokeColor: root.items[root.sel].hold ? "#e06c75" : root.accent; fillColor: "transparent"; capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: dial.width / 2; centerY: dial.height / 2; radiusX: dial.r - 26; radiusY: dial.r - 26; startAngle: -90; sweepAngle: 359.9 * root.fill }
      }
    }

    // центр: часы, действие, подсказка
    Column {
      anchors.centerIn: parent
      spacing: 6
      Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(root.now, "hh:mm"); font.family: root.font; font.pixelSize: 44; color: root.fg }
      Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.items[root.sel].l; font.family: root.font; font.pixelSize: 16; color: root.accent }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.items[root.sel].hold ? "hold to confirm" : "click or enter"
        font.family: root.font; font.pixelSize: 11; color: root.a(root.fg, 0.45)
      }
      Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.uptime ? "up " + root.uptime : ""; font.family: root.font; font.pixelSize: 11; color: root.a(root.fg, 0.35) }
    }

    // мышь: угол от центра выбирает сектор; нажатие — действие / удержание
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton
      function secAt(x, y) {
        const dx = x - width / 2, dy = y - height / 2
        if (Math.hypot(dx, dy) < dial.r - 60) return -1
        const deg = (Math.atan2(dx, -dy) * 180 / Math.PI + 360 + 180 / root.n) % 360
        return Math.floor(deg / (360 / root.n))
      }
      onPositionChanged: m => { const s = secAt(m.x, m.y); if (s >= 0 && !holding.running) root.sel = s }
      onPressed: m => { const s = secAt(m.x, m.y); if (s >= 0) root.press(s) }
      onReleased: root.release()
      onWheel: w => { if (!holding.running) root.sel = (root.sel + (w.angleDelta.y < 0 ? 1 : -1) + root.n) % root.n }
    }

    Repeater {
      model: root.n
      Rectangle {
        id: btn
        required property int index
        readonly property real t: index * 2 * Math.PI / root.n
        readonly property bool on: index === root.sel
        width: on ? 64 : 54; height: width; radius: width / 2
        x: dial.width / 2 + Math.sin(t) * dial.r - width / 2
        y: dial.height / 2 - Math.cos(t) * dial.r - height / 2
        color: on ? root.accent : root.a(root.fg, 0.08)
        Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 160 } }
        Text { anchors.centerIn: parent; text: root.items[btn.index].g; font.family: root.font; font.pixelSize: 22; color: btn.on ? root.bg : root.fg }
      }
    }
  }

  Item {
    id: keys
    focus: root.open
    Keys.onPressed: e => {
      if (e.isAutoRepeat && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)) { e.accepted = true; return }
      if (e.key === Qt.Key_Escape) root.close()
      else if (e.key === Qt.Key_Right || e.key === Qt.Key_Down || e.key === Qt.Key_Tab || e.key === Qt.Key_L || e.key === Qt.Key_J) { if (!holding.running) root.sel = (root.sel + 1) % root.n }
      else if (e.key === Qt.Key_Left || e.key === Qt.Key_Up || e.key === Qt.Key_Backtab || e.key === Qt.Key_H || e.key === Qt.Key_K) { if (!holding.running) root.sel = (root.sel - 1 + root.n) % root.n }
      else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) root.press(root.sel)
      else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_5) root.sel = e.key - Qt.Key_1
      else return
      e.accepted = true
    }
    Keys.onReleased: e => {
      if (e.isAutoRepeat) return
      if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) { root.release(); e.accepted = true }
    }
  }
}

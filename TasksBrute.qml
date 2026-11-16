import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Панель «Tasks» Bruteon (по мотивам Bruteon, Darkkal44 — облик с его скриншота, код свой): открывается кнопкой Tasks
// на баре (omarchy-shell widgets toggleTasks) у левого края под баром, поверх окон. Две карточки необрутализма:
//   Tasks — «✎ Tasks · N active», поле «What needs to be done?» с плитками ⏱ (запустить помодоро) и + (добавить),
//           список с квадратными флажками; задачи — тот же файл, что у виджета Todo (~/.config/omarchy/widgets-todo.json);
//           правый клик по задаче — удалить;
//   Pomodoro / Stopwatch — переключатель режимов; у помодоро — Focus 25 / Break 5 / Long 15, крупное время в розовой
//           двойной рамке с подписью «• FOCUS SESSION •», плитки «сначала», «пуск / пауза», «длительность»
//           (⚙ — фокус 25 ↔ 50 мин); по окончании — уведомление. Таймер идёт и при закрытой панели.
// Esc или повторный клик по Tasks — закрыть.
PanelWindow {
  id: tp

  required property var host
  readonly property bool open: host.tasksOpen === true
  property real k: open ? 1 : 0
  Behavior on k { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }

  readonly property color ink: "#161110"
  readonly property color card: host.background
  readonly property color tileC: "#fbf3ee"
  readonly property color muted: "#885643"
  readonly property color green: "#c5e1a5"
  readonly property color pink: "#ffcbd5"
  readonly property color salmon: "#ffb3a1"
  readonly property color lavender: "#dcc4ec"
  readonly property string mono: Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : host.fontFamily

  screen: host.focusedScreen
  visible: open || k > 0.01
  anchors { top: true; left: true }
  margins { top: 8; left: 14 }
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: 0
  implicitWidth: 400
  implicitHeight: col.implicitHeight + 16
  color: "transparent"
  WlrLayershell.namespace: "omarchy-tasks"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  onOpenChanged: if (open) entry.forceActiveFocus()

  // ── задачи: файл виджета Todo ──
  readonly property string path: Quickshell.env("HOME") + "/.config/omarchy/widgets-todo.json"
  property var items: []
  FileView {
    id: store
    path: tp.path
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { var v = JSON.parse(text() || "[]"); tp.items = Array.isArray(v) ? v : [] } catch (e) { tp.items = [] } }
    onLoadFailed: tp.items = []
  }
  // новый файл — с правами 0600, как у виджета Todo
  Process {
    id: ensure
    command: ["bash", "-c", "umask 077; mkdir -p -- \"${1%/*}\" && { [[ -e $1 ]] || printf '[]\\n' > \"$1\"; } && chmod 600 -- \"$1\"", "--", tp.path]
  }
  Component.onCompleted: ensure.running = true
  function save(list) { tp.items = list; store.setText(JSON.stringify(list, null, 2) + "\n") }
  function add(t) { t = String(t).trim(); if (t) save(tp.items.concat([{ text: t, done: false }])) }
  function toggle(i) { var l = tp.items.slice(); l[i] = { text: l[i].text, done: !l[i].done }; save(l) }
  function remove(i) { var l = tp.items.slice(); l.splice(i, 1); save(l) }
  readonly property int active: items.filter(function(x) { return !x.done }).length

  // ── помодоро / секундомер ──
  property string mode: "pomodoro"          // pomodoro | stopwatch
  property string phase: "focus"            // focus | break | long
  property int focusMin: 25
  readonly property int phaseLen: (phase === "focus" ? focusMin : phase === "break" ? 5 : 15) * 60
  property int remain: phaseLen
  property int watch: 0
  property bool running: false
  onPhaseLenChanged: if (!running) remain = phaseLen
  Timer {
    interval: 1000; repeat: true; running: tp.running
    onTriggered: {
      if (tp.mode === "stopwatch") { tp.watch++; return }
      if (tp.remain > 0) tp.remain--
      if (tp.remain === 0) {
        tp.running = false
        Quickshell.execDetached(["notify-send", "-a", "Pomodoro", tp.phase === "focus" ? "Focus session done" : "Break is over",
                                 tp.phase === "focus" ? "Time for a break" : "Back to work"])
        tp.phase = tp.phase === "focus" ? "break" : "focus"
        tp.remain = tp.phaseLen
      }
    }
  }
  function mmss(x) { return ("0" + Math.floor(x / 60)).slice(-2) + ":" + ("0" + (x % 60)).slice(-2) }

  // ── детали ──
  component Card: Item {
    id: cc
    default property alias content: ccFace.data
    Rectangle { x: 5; y: 5; width: cc.width; height: cc.height; radius: 12; color: tp.ink }
    Rectangle { id: ccFace; width: cc.width; height: cc.height; radius: 12; color: tp.card; border.width: 2.5; border.color: tp.ink }
  }
  component Tile: Item {
    id: tl
    default property alias content: tlFace.data
    property color fill: tp.tileC
    property real r: 7
    property real sh: 2.5
    signal clicked()
    readonly property real lift: tlTap.pressed ? 0 : tlHov.hovered ? sh + 1 : sh
    Rectangle { x: tl.sh; y: tl.sh; width: tl.width; height: tl.height; radius: tl.r; color: tp.ink }
    Rectangle {
      id: tlFace
      x: tl.sh - tl.lift; y: tl.sh - tl.lift
      width: tl.width; height: tl.height; radius: tl.r
      color: tl.fill; border.width: 2; border.color: tp.ink
      Behavior on x { NumberAnimation { duration: 80 } }
      Behavior on y { NumberAnimation { duration: 80 } }
    }
    HoverHandler { id: tlHov; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tlTap; onTapped: tl.clicked() }
  }
  component Lbl: Text { font.family: tp.mono; color: tp.ink }

  Column {
    id: col
    x: 4; y: 4
    spacing: 16
    opacity: Math.min(1, tp.k * 1.4)
    transform: Translate { y: (1 - tp.k) * -14 }
    focus: true
    Keys.onEscapePressed: tp.host.tasksOpen = false

    // ── Tasks ──
    Card {
      width: 380; height: Math.max(200, 120 + list.contentHeight)
      Row { x: 16; y: 16; spacing: 8
        Lbl { text: ""; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
        Lbl { text: "Tasks"; font.pixelSize: 15; font.bold: true; anchors.verticalCenter: parent.verticalCenter } }
      Lbl { anchors.right: parent.right; anchors.rightMargin: 18; y: 19; text: tp.active + " active"; font.pixelSize: 10; color: tp.muted }
      Tile {
        x: 14; y: 50; width: 346; height: 42; r: 9; sh: 3
        TextInput {
          id: entry
          x: 12; width: parent.width - 90
          anchors.verticalCenter: parent.verticalCenter
          font.family: tp.mono; font.pixelSize: 12; color: tp.ink
          clip: true
          onAccepted: { tp.add(text); text = "" }
          Lbl { visible: !entry.text; text: "What needs to be done?"; font.pixelSize: 12; color: tp.muted; anchors.verticalCenter: parent.verticalCenter }
        }
        Row {
          anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
          spacing: 8
          Tile { width: 22; height: 22; r: 6; sh: 1.5; onClicked: { tp.mode = "pomodoro"; tp.phase = "focus"; tp.running = true }
            Lbl { anchors.centerIn: parent; text: ""; font.pixelSize: 10 } }
          Tile { width: 22; height: 22; r: 6; sh: 1.5; fill: tp.pink; onClicked: { tp.add(entry.text); entry.text = "" }
            Lbl { anchors.centerIn: parent; text: "+"; font.pixelSize: 13; font.bold: true } }
        }
      }
      ListView {
        id: list
        x: 18; y: 108
        width: 344; height: Math.min(contentHeight, 220)
        clip: true
        spacing: 14
        model: tp.items
        delegate: Item {
          required property var modelData
          required property int index
          width: list.width; height: 22
          Rectangle {
            id: box
            width: 20; height: 20; radius: 5
            anchors.verticalCenter: parent.verticalCenter
            color: modelData.done ? tp.green : tp.tileC
            border.width: 2; border.color: tp.ink
            Lbl { anchors.centerIn: parent; visible: modelData.done; text: ""; font.pixelSize: 10 }
          }
          Lbl {
            x: 32; anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 32; elide: Text.ElideRight
            text: modelData.text; font.pixelSize: 12; font.bold: true
            font.strikeout: modelData.done; opacity: modelData.done ? 0.5 : 1
          }
          TapHandler { acceptedButtons: Qt.LeftButton | Qt.RightButton
            onTapped: function(ev, b) { if (b === Qt.RightButton) tp.remove(index); else tp.toggle(index) } }
          HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
      }
    }

    // ── Pomodoro / Stopwatch ──
    Card {
      width: 380; height: 216
      Row {
        anchors.horizontalCenter: parent.horizontalCenter; y: 14
        spacing: 12
        Repeater {
          model: [["pomodoro", "Pomodoro"], ["stopwatch", "Stopwatch"]]
          Rectangle {
            required property var modelData
            readonly property bool on: tp.mode === modelData[0]
            width: ml.implicitWidth + 22; height: 24; radius: 12
            color: on ? tp.green : tp.tileC; border.width: 2; border.color: tp.ink
            Lbl { id: ml; anchors.centerIn: parent; text: parent.modelData[1]; font.pixelSize: 10; font.bold: true }
            TapHandler { onTapped: { tp.mode = parent.modelData[0]; tp.running = false } }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
          }
        }
      }
      Column {
        visible: tp.mode === "pomodoro"
        x: 12; y: 88
        spacing: 8
        Repeater {
          model: [["focus", "Focus"], ["break", "Break"], ["long", "Long"]]
          Rectangle {
            required property var modelData
            readonly property bool on: tp.phase === modelData[0]
            width: 54; height: 20; radius: 10
            color: on ? tp.pink : tp.tileC; border.width: 1.8; border.color: tp.ink
            Lbl { anchors.centerIn: parent; text: parent.modelData[1]; font.pixelSize: 9; font.bold: true }
            TapHandler { onTapped: { tp.running = false; tp.phase = parent.modelData[0]; tp.remain = tp.phaseLen } }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
          }
        }
      }
      // время в розовой двойной рамке
      Rectangle {
        x: 78; y: 64; width: 222; height: 104; radius: 22
        color: tp.pink; border.width: 2; border.color: tp.ink
        Rectangle {
          anchors.fill: parent; anchors.margins: 8; radius: 15
          color: tp.card; border.width: 2; border.color: tp.ink
          Column {
            anchors.centerIn: parent
            spacing: 4
            Lbl { anchors.horizontalCenter: parent.horizontalCenter; text: tp.mode === "stopwatch" ? tp.mmss(tp.watch) : tp.mmss(tp.remain); font.pixelSize: 34; font.bold: true }
            Lbl {
              anchors.horizontalCenter: parent.horizontalCenter
              text: tp.mode === "stopwatch" ? "• STOPWATCH •" : tp.phase === "focus" ? "• FOCUS SESSION •" : tp.phase === "break" ? "• SHORT BREAK •" : "• LONG BREAK •"
              font.pixelSize: 9; font.letterSpacing: 1.5; color: "#c26b7f"
            }
          }
        }
      }
      Column {
        x: 322; y: 72
        spacing: 10
        Tile { width: 26; height: 26; r: 13; sh: 2; fill: tp.lavender
          onClicked: { tp.running = false; if (tp.mode === "stopwatch") tp.watch = 0; else tp.remain = tp.phaseLen }
          Lbl { anchors.centerIn: parent; text: ""; font.pixelSize: 10 } }
        Tile { width: 26; height: 26; r: 13; sh: 2; fill: tp.salmon; onClicked: tp.running = !tp.running
          Lbl { anchors.centerIn: parent; text: tp.running ? "" : ""; font.pixelSize: 10 } }
        Tile { width: 26; height: 26; r: 13; sh: 2; fill: tp.pink
          onClicked: { tp.focusMin = tp.focusMin === 25 ? 50 : 25; if (!tp.running && tp.phase === "focus") tp.remain = tp.phaseLen }
          Lbl { anchors.centerIn: parent; text: ""; font.pixelSize: 10 } }
      }
      Lbl {
        visible: tp.mode === "pomodoro"
        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 12
        text: "focus " + tp.focusMin + " · break 5 · long 15 min"
        font.pixelSize: 8; color: tp.muted
      }
    }
  }
}

import QtQuick
import Quickshell
import Quickshell.Io

// Таймер и будильник для всех райсов (полоса под плеером — TimerStrip.qml, IPC widgets timerStart / timerCancel /
// alarmSet / alarmToggle / timerDismiss). Состояние — ~/.local/state/omarchy/timer.json, поэтому переживает
// перезапуск шелла: { timerEnd: мс эпохи, timerLen: мс, alarm: "HH:MM", alarmOn, alarmLast: "ГГГГ-ММ-ДД" }.
// Срабатывание — по мотивам его Modern/bar/Alarm.qml (elifouts/Dotfiles, GPL-3.0): уведомление, его alarm.ogg пять
// раз (ffplay) и открытая панель плеера с колокольчиком; dismiss() — тишина.
Item {
  id: ts
  required property var host

  readonly property string file: Quickshell.env("HOME") + "/.local/state/omarchy/timer.json"
  property real timerEnd: 0
  property real timerLen: 0
  property string alarm: "07:00"
  property bool alarmOn: false
  property string alarmLast: ""
  property bool ringing: false
  property string ringLabel: ""
  property real now: Date.now()

  readonly property bool running: timerEnd > 0
  readonly property real remaining: running ? Math.max(0, timerEnd - now) : 0
  readonly property real frac: running && timerLen > 0 ? remaining / timerLen : 0
  function fmt(ms) {
    const s = Math.ceil(ms / 1000), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), x = s % 60
    return (h ? h + ":" + String(m).padStart(2, "0") : String(m)) + ":" + String(x).padStart(2, "0")
  }

  FileView {
    id: store
    path: ts.file
    printErrors: false
    onLoaded: {
      try {
        const d = JSON.parse(text())
        ts.timerEnd = Number(d.timerEnd) || 0
        ts.timerLen = Number(d.timerLen) || 0
        ts.alarm = String(d.alarm || "07:00")
        ts.alarmOn = !!d.alarmOn
        ts.alarmLast = String(d.alarmLast || "")
      } catch (e) {}
    }
  }
  function save() {
    store.setText(JSON.stringify({ timerEnd: timerEnd, timerLen: timerLen, alarm: alarm, alarmOn: alarmOn, alarmLast: alarmLast }))
  }

  function start(minutes) {
    const ms = Math.max(1, Number(minutes) || 0) * 60000
    timerLen = ms
    timerEnd = Date.now() + ms
    now = Date.now()
    save()
  }
  function add(minutes) { if (running) { timerEnd += minutes * 60000; timerLen += minutes * 60000; save() } else start(minutes) }
  function cancel() { timerEnd = 0; timerLen = 0; save() }
  function setAlarm(hhmm) {
    const m = String(hhmm).match(/^(\d{1,2}):?(\d{2})$/)
    if (!m) return
    alarm = String(Math.min(23, Number(m[1]))).padStart(2, "0") + ":" + String(Math.min(59, Number(m[2]))).padStart(2, "0")
    alarmOn = true
    alarmLast = ""
    save()
  }
  function shiftAlarm(minutes) {
    const p = alarm.split(":").map(Number)
    let t = ((p[0] * 60 + p[1] + minutes) % 1440 + 1440) % 1440
    alarm = String(Math.floor(t / 60)).padStart(2, "0") + ":" + String(t % 60).padStart(2, "0")
    alarmLast = ""
    save()
  }
  function toggleAlarm() { alarmOn = !alarmOn; alarmLast = ""; save() }

  function ring(label) {
    ringLabel = label
    ringing = true
    host.playerOpen = true
    Quickshell.execDetached(["notify-send", "-a", "Timer", "-u", "critical", "󰀠  Time's up", label])
  }
  function dismiss() { ringing = false }

  Process {
    running: ts.ringing
    command: ["ffplay", "-nodisp", "-loop", "5", "-loglevel", "quiet", String(Qt.resolvedUrl("sounds/alarm.ogg")).replace(/^file:\/\//, "")]
    onExited: ts.ringing = false
  }

  Timer {
    interval: 1000; repeat: true
    running: ts.running || ts.alarmOn
    triggeredOnStart: true
    onTriggered: {
      ts.now = Date.now()
      if (ts.running && ts.now >= ts.timerEnd) {
        const len = ts.fmt(ts.timerLen)
        ts.cancel()
        ts.ring("Your " + len + " timer has finished.")
      }
      if (ts.alarmOn) {
        const d = new Date(), day = Qt.formatDate(d, "yyyy-MM-dd")
        if (Qt.formatTime(d, "HH:mm") === ts.alarm && ts.alarmLast !== day) {
          ts.alarmLast = day
          ts.save()
          ts.ring("Alarm " + ts.alarm)
        }
      }
    }
  }
}

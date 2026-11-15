import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Общее состояние панелей surface (Hub в Super+M — SurfaceHub.qml, дашборд — DashSurface.qml): сеть, Bluetooth,
// профиль питания, яркость, ночной свет, «не засыпать», режим чтения, запись экрана, DND, звук и микрофон,
// последние уведомления, напоминания. Опрос — пока live (панель открыта), раз в 3 с; команды — те же, что у
// панели Super+M и Quick.
QtObject {
  id: st
  property bool live: false
  property string readingScript: Quickshell.env("HOME") + "/.config/omarchy/plugins/kamradsmeshnyavy.customizer/scripts/reading-mode.sh"

  property bool wifi: false
  property string ssid: ""
  property bool bt: false
  property string profile: ""
  property real bright: -1
  property bool night: false
  property bool caffeine: false
  property bool reading: false
  property bool rec: false
  property bool dnd: false
  property var notes: []
  property var reminders: []
  property string uptime: ""

  readonly property PwNode sink: Pipewire.defaultAudioSink
  readonly property PwNode source: Pipewire.defaultAudioSource
  readonly property real vol: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool muted: !!(sink && sink.audio && sink.audio.muted)
  readonly property real micVol: source && source.audio ? source.audio.volume : 0
  readonly property bool micMuted: !!(source && source.audio && source.audio.muted)
  property PwObjectTracker tracker: PwObjectTracker { objects: [st.sink, st.source] }

  property Process stateRead: Process {
    command: ["sh", "-c",
      "l() { printf '%s\\n' \"$(\"$@\" 2>/dev/null | head -1)\"; }; " +
      "l nmcli -t -f WIFI g; " +
      "l sh -c \"nmcli -t -f NAME,TYPE connection show --active | grep -v ':loopback' | grep -v ':tun' | head -1 | cut -d: -f1\"; " +
      "l sh -c \"bluetoothctl show | grep -q 'Powered: yes' && echo on || echo off\"; " +
      "l powerprofilesctl get; " +
      "l brightnessctl -m; " +
      "l omarchy-toggle-nightlight --status; " +
      "l sh -c 'omarchy-toggle-idle status | jq -c .enabled'; " +
      "l \"$1\" status; " +
      "l sh -c 'omarchy-capture-screenrecording --status >/dev/null 2>&1 && echo true'; " +
      "l uptime -p",
      "_", st.readingScript]
    stdout: StdioCollector {
      onStreamFinished: {
        var l = String(text || "").split("\n")
        st.wifi = (l[0] || "").trim() === "enabled"
        st.ssid = (l[1] || "").trim()
        st.bt = (l[2] || "").trim() === "on"
        st.profile = (l[3] || "").trim()
        var b = (l[4] || "").split(",")
        st.bright = b.length > 3 ? Math.max(0, Math.min(1, parseFloat(b[3]) / 100)) : -1
        try { st.night = JSON.parse(l[5] || "{}").enabled === true } catch (e) { st.night = false }
        st.caffeine = (l[6] || "").trim() === "true"
        st.reading = (l[7] || "").trim() === "on"
        st.rec = (l[8] || "").trim() === "true"
        st.uptime = (l[9] || "").trim().replace(/^up\s+/, "")
      }
    }
  }
  property Process notesRead: Process {
    command: ["python3", "-c",
      "import glob, json, os\n" +
      "p = os.path.expanduser('~/.local/state/omarchy/notifications/history/*.json')\n" +
      "out = []\n" +
      "for f in sorted(glob.glob(p), key=os.path.getmtime, reverse=True)[:8]:\n" +
      "  try:\n" +
      "    with open(f) as fh: out.append(json.load(fh))\n" +
      "  except Exception: pass\n" +
      "print(json.dumps(out))"]
    stdout: StdioCollector { onStreamFinished: { try { st.notes = JSON.parse(String(text || "[]")) || [] } catch (e) { st.notes = [] } } }
  }
  property Process remRead: Process {
    command: ["omarchy-reminder", "show", "--json"]
    stdout: StdioCollector { onStreamFinished: { try { st.reminders = JSON.parse(text).reminders || [] } catch (e) { st.reminders = [] } } }
  }
  property FileView dndFile: FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/notifications.json"
    watchChanges: true; printErrors: false
    onLoaded: { try { st.dnd = JSON.parse(text() || "{}").dnd === true } catch (e) { st.dnd = false } }
    onFileChanged: reload()
  }
  function refresh() {
    if (!stateRead.running) stateRead.running = true
    if (!notesRead.running) notesRead.running = true
    if (!remRead.running) remRead.running = true
  }
  onLiveChanged: if (live) refresh()
  property Timer poll: Timer { interval: 3000; repeat: true; running: st.live; onTriggered: st.refresh() }
  property Timer later: Timer { interval: 700; onTriggered: st.refresh() }
  function run(a) { Quickshell.execDetached(a); later.restart() }

  // ── действия ──
  function toggleWifi() { wifi = !wifi; run(["nmcli", "radio", "wifi", wifi ? "on" : "off"]) }
  function toggleBt() { bt = !bt; run(["bluetoothctl", "power", bt ? "on" : "off"]) }
  function cycleProfile() { run(["sh", "-c", "case $(powerprofilesctl get) in balanced) powerprofilesctl set performance;; performance) powerprofilesctl set power-saver;; *) powerprofilesctl set balanced;; esac"]) }
  function toggleDnd() { dnd = !dnd; Quickshell.execDetached(["omarchy-shell", "notifications", "toggleDnd"]) }
  function toggleNight() { night = !night; run(["omarchy-toggle-nightlight"]) }
  function toggleCaffeine() { caffeine = !caffeine; run(["omarchy-toggle-idle"]) }
  function toggleReading() { reading = !reading; run([readingScript, "toggle"]) }
  function toggleMic() { if (source && source.audio) source.audio.muted = !source.audio.muted }
  function setBright(v) { bright = Math.max(0.02, v); Quickshell.execDetached(["brightnessctl", "-q", "set", Math.round(bright * 100) + "%"]) }
  function setVol(v) { if (sink && sink.audio) { sink.audio.muted = false; sink.audio.volume = v } }
  function setMic(v) { if (source && source.audio) { source.audio.muted = false; source.audio.volume = v } }
  function clearNotes() {
    notes = []
    Quickshell.execDetached(["sh", "-c", "omarchy-shell notifications dismissAll >/dev/null 2>&1; omarchy-shell notifications clear >/dev/null 2>&1"])
  }
  // тёмная ↔ светлая тема surface (как его клавиши d / l)
  function setMode(dark) {
    Quickshell.execDetached(["bash", "-c",
      "t=$(cat \"$HOME/.local/state/omarchy/current/theme.name\" 2>/dev/null); case \"$t\" in surface-*) ;; *) t=surface-dark;; esac; " +
      "n=$(printf %s \"$t\" | sed " + (dark ? "'s/light/dark/'" : "'s/dark/light/'") + "); [ \"$n\" = \"$t\" ] || omarchy theme set \"$n\""])
  }
}

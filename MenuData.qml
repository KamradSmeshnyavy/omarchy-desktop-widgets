import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Данные и действия меню Super+M райсов (MenuBrute, MenuYami, MenuCozy, MenuRumda, MenuGlass, MenuDots): всё, что есть
// у SurfState (переключатели, громкость, яркость, uptime, уведомления), плюс списки — сети Wi-Fi (nmcli), устройства
// Bluetooth (bluetoothctl), выходы звука (Pipewire). Списки опрашиваются, пока live; scan() — пересканировать.
Item {
  id: md
  property bool live: false
  readonly property alias st: state_
  SurfState { id: state_; live: md.live }

  property var networks: []      // [{ssid, signal, secure, active}]
  property var devices: []       // [{mac, name, connected, paired}]
  readonly property var sinks: Pipewire.nodes.values.filter(function(n) { return n.isSink && !n.isStream && n.audio })
  readonly property var defaultSink: Pipewire.defaultAudioSink
  PwObjectTracker { objects: md.sinks }

  Process {
    id: wifiProc
    command: ["sh", "-c", "nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list 2>/dev/null | head -40"]
    stdout: StdioCollector {
      onStreamFinished: {
        var seen = ({}), out = []
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var p = lines[i].replace(/\\:/g, "\u0001").split(":")
          if (p.length < 4 || !p[1]) continue
          var ssid = p[1].replace(/\u0001/g, ":")
          var e = { ssid: ssid, signal: parseInt(p[2]) || 0, secure: (p[3] || "") !== "" && p[3] !== "--", active: p[0] === "*" }
          if (seen[ssid] && (seen[ssid].active || seen[ssid].signal >= e.signal) && !e.active) continue
          seen[ssid] = e
        }
        for (var k in seen) out.push(seen[k])
        out.sort(function(a, b) { return (b.active - a.active) || (b.signal - a.signal) })
        md.networks = out
      }
    }
  }
  Process {
    id: btProc
    command: ["sh", "-c", "bluetoothctl devices 2>/dev/null | while read -r _ mac name; do i=$(bluetoothctl info \"$mac\" 2>/dev/null); " +
      "c=$(printf '%s' \"$i\" | grep -q 'Connected: yes' && echo 1 || echo 0); p=$(printf '%s' \"$i\" | grep -q 'Paired: yes' && echo 1 || echo 0); " +
      "printf '%s\\t%s\\t%s\\t%s\\n' \"$mac\" \"$c\" \"$p\" \"$name\"; done"]
    stdout: StdioCollector {
      onStreamFinished: {
        var out = []
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var p = lines[i].split("\t")
          if (p.length < 4) continue
          out.push({ mac: p[0], connected: p[1] === "1", paired: p[2] === "1", name: p[3] })
        }
        out.sort(function(a, b) { return (b.connected - a.connected) || (b.paired - a.paired) })
        md.devices = out
      }
    }
  }
  function scan() {
    if (!wifiProc.running) wifiProc.running = true
    if (!btProc.running) btProc.running = true
  }
  onLiveChanged: if (live) scan()
  Timer { interval: 6000; repeat: true; running: md.live; onTriggered: md.scan() }
  Timer { id: later; interval: 1500; onTriggered: md.scan() }
  function run(a) { Quickshell.execDetached(a); later.restart() }

  // ── действия ──
  function connectWifi(ssid, password) {
    if (password && password.length) run(["nmcli", "dev", "wifi", "connect", ssid, "password", password])
    else run(["nmcli", "dev", "wifi", "connect", ssid])
  }
  function disconnectWifi(ssid) { run(["nmcli", "con", "down", "id", ssid]) }
  function toggleDevice(d) { run(["bluetoothctl", d.connected ? "disconnect" : "connect", d.mac]) }
  function scanBt() { run(["sh", "-c", "timeout 8 bluetoothctl --timeout 8 scan on >/dev/null 2>&1"]) }
  function setSink(n) { if (n) Pipewire.preferredDefaultAudioSink = n }
  function sinkName(n) { return n ? String(n.description || n.nickname || n.name || "") : "" }
}

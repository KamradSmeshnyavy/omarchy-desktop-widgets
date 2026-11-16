import QtQuick
import Quickshell.Io

// Загрузка системы для дашбордов: cpu, mem, disk, temp — доли 0…1, и история cpu / mem (последние 30 замеров).
// Опрос раз в 2 с, пока live.
QtObject {
  id: s
  property bool live: false
  property real cpu: 0
  property real mem: 0
  property real disk: 0
  property real temp: 0
  property var cpuHist: []
  property var memHist: []
  property var prev: null
  function push(a, v) { var b = a.slice(-29); b.push(v); return b }
  property Process probe: Process {
    command: ["bash", "-c", "read -r _ u ni sy i w q sq stl _ < /proc/stat; echo cpu $((u+ni+sy+i+w+q+sq+stl)) $((i+w));" +
      "awk '/^MemTotal|^MemAvailable/{printf \"%s \", $2} END{print \"\"}' /proc/meminfo | sed 's/^/mem /';" +
      "df -P / | awk 'NR==2{print \"disk\", $5}';" +
      "t=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1); echo temp ${t:-0}"]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var x = lines[i].trim().split(/\s+/)
          if (x[0] === "cpu") {
            var tot = Number(x[1]), idle = Number(x[2])
            if (s.prev && tot > s.prev.total) { s.cpu = Math.max(0, Math.min(1, 1 - (idle - s.prev.idle) / (tot - s.prev.total))); s.cpuHist = s.push(s.cpuHist, s.cpu) }
            s.prev = { total: tot, idle: idle }
          } else if (x[0] === "mem" && Number(x[1]) > 0) { s.mem = 1 - Number(x[2]) / Number(x[1]); s.memHist = s.push(s.memHist, s.mem) }
          else if (x[0] === "disk") s.disk = parseInt(x[1]) / 100
          else if (x[0] === "temp") s.temp = Math.min(1, Number(x[1]) / 1000 / 100)
        }
      }
    }
  }
  property Timer poll: Timer { interval: 2000; repeat: true; running: s.live; triggeredOnStart: true; onTriggered: if (!s.probe.running) s.probe.running = true }
}

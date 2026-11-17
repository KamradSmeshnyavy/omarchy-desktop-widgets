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

  property var networks: []      // [{ssid, signal, secure, active, saved, uuid}]
  property var saved: ({})       // ssid → uuid сохранённого профиля NetworkManager (пароль уже есть — не спрашивать)
  property var savedList: []     // [{ssid, uuid}] — все сохранённые, в том числе вне зоны
  property string wifiDev: ""
  property string wifiMsg: ""    // строка состояния: «connecting…», ошибка nmcli
  property bool wifiBusy: false
  property bool hold: false      // пока вводится пароль / имя сети — список не обновлять (строки не пересоздавать)
  property var info: ({})        // подробности открытого профиля (details): поле nmcli → значение / список
  property string infoUuid: ""
  property string psk: ""        // показанный пароль (showPassword)
  property var devices: []       // [{mac, name, connected, paired, trusted, battery}]
  readonly property var sinks: Pipewire.nodes.values.filter(function(n) { return n.isSink && !n.isStream && n.audio })
  readonly property var sources: Pipewire.nodes.values.filter(function(n) { return !n.isSink && !n.isStream && n.audio && String(n.name || "").indexOf(".monitor") === -1 })
  readonly property var defaultSink: Pipewire.defaultAudioSink
  readonly property var defaultSource: Pipewire.defaultAudioSource
  PwObjectTracker { objects: md.sinks.concat(md.sources) }

  // DNS-пресеты: [имя, ipv4, ipv6]; «auto» — DNS от роутера (DHCP)
  readonly property var dnsPresets: [
    ["auto", "", ""],
    ["Cloudflare", "1.1.1.1 1.0.0.1", "2606:4700:4700::1111 2606:4700:4700::1001"],
    ["Google", "8.8.8.8 8.8.4.4", "2001:4860:4860::8888 2001:4860:4860::8844"],
    ["Quad9", "9.9.9.9 149.112.112.112", "2620:fe::fe 2620:fe::9"],
    ["AdGuard", "94.140.14.14 94.140.15.15", "2a10:50c0::ad1:ff 2a10:50c0::ad2:ff"],
    ["Yandex", "77.88.8.8 77.88.8.1", "2a02:6b8::feed:0ff 2a02:6b8:0:1::feed:0ff"]
  ]

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
        md.decorate(out)
      }
    }
  }
  property var rawNets: []
  function decorate(list) {
    if (list) rawNets = list
    // сигнал — ступенями по 25 (как полоски ▂▄▆█): иначе список менялся бы на каждом опросе
    var out = rawNets.map(function(n) { return { ssid: n.ssid, signal: Math.max(25, Math.ceil(n.signal / 25) * 25), secure: n.secure, active: n.active, saved: !!saved[n.ssid], uuid: saved[n.ssid] || "" } })
    out.sort(function(a, b) { return (b.active - a.active) || (b.saved - a.saved) || (b.signal - a.signal) })
    // новый массив пересоздаёт строки Repeater — выбор с клавиатуры и набранный пароль пропали бы; только при изменении
    if (JSON.stringify(out) !== JSON.stringify(networks)) networks = out
  }
  // сохранённые профили Wi-Fi: uuid → ssid (имя профиля может не совпадать с ssid)
  Process {
    id: savedProc
    command: ["sh", "-c", "nmcli -t -f DEVICE,TYPE dev 2>/dev/null | grep ':wifi$' | head -1 | cut -d: -f1; " +
      "nmcli -t -f UUID,TYPE con show 2>/dev/null | while IFS=: read -r u t; do [ \"$t\" = 802-11-wireless ] || continue; " +
      "printf '%s\\t%s\\n' \"$u\" \"$(nmcli -g 802-11-wireless.ssid con show \"$u\" 2>/dev/null)\"; done"]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.split("\n"), map = ({}), list = []
        md.wifiDev = (lines[0] || "").trim()
        for (var i = 1; i < lines.length; i++) {
          var t = lines[i].indexOf("\t")
          if (t < 0) continue
          var ssid = lines[i].slice(t + 1).replace(/\\:/g, ":").replace(/\\\\/g, "\\")
          if (!ssid || map[ssid]) continue
          map[ssid] = lines[i].slice(0, t); list.push({ ssid: ssid, uuid: map[ssid] })
        }
        list.sort(function(a, b) { return a.ssid.localeCompare(b.ssid) })
        if (JSON.stringify(list) !== JSON.stringify(md.savedList)) { md.saved = map; md.savedList = list }
        md.decorate(null)
      }
    }
  }
  // подробности профиля: строки «поле:значение» (nmcli -t), поля с [n] — списки
  Process {
    id: infoProc
    property string uuid: ""
    command: ["nmcli", "-t", "-f", "connection.id,connection.autoconnect,ipv4.method,ipv4.dns,ipv4.ignore-auto-dns,ipv6.dns," +
      "802-11-wireless.ssid,802-11-wireless-security.key-mgmt,GENERAL.STATE,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS,IP6.DNS", "con", "show", "uuid", uuid]
    stdout: StdioCollector {
      onStreamFinished: {
        var o = ({}), lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var c = lines[i].indexOf(":")
          if (c < 0) continue
          var key = lines[i].slice(0, c).replace(/\[\d+\]$/, ""), v = lines[i].slice(c + 1).replace(/\\:/g, ":")
          if (lines[i].slice(0, c) !== key) { if (!o[key]) o[key] = []; o[key].push(v) } else o[key] = v
        }
        if (JSON.stringify(o) !== JSON.stringify(md.info)) md.info = o
      }
    }
  }
  Process {
    id: pskProc
    property string uuid: ""
    command: ["nmcli", "-s", "-g", "802-11-wireless-security.psk", "con", "show", "uuid", uuid]
    stdout: StdioCollector { onStreamFinished: md.psk = text.trim() || "—" }
  }
  // подключение с отчётом: nmcli ждёт, пока сеть поднимется, и печатает ошибку
  Process {
    id: actProc
    property string label: ""
    stdout: StdioCollector { id: actOut }
    stderr: StdioCollector { id: actErr }
    onExited: function(code) {
      md.wifiBusy = false
      var msg = (actErr.text + "\n" + actOut.text).trim().split("\n").filter(function(l) { return l.trim() !== "" })
      md.wifiMsg = code === 0 ? "" : "✗ " + (msg.length ? msg[msg.length - 1].replace(/^Error: /, "") : label + " failed")
      md.refreshWifi()
      if (md.infoUuid !== "") md.details(md.infoUuid)
    }
  }
  function act(label, cmd) {
    if (actProc.running) return
    wifiMsg = label + "…"; wifiBusy = true
    actProc.label = label; actProc.command = cmd; actProc.running = true
  }
  function refreshWifi() {
    if (hold) return
    if (!wifiProc.running) wifiProc.running = true
    if (!savedProc.running) savedProc.running = true
  }
  Process {
    id: btProc
    command: ["sh", "-c", "bluetoothctl devices 2>/dev/null | while read -r _ mac name; do i=$(bluetoothctl info \"$mac\" 2>/dev/null); " +
      "c=$(printf '%s' \"$i\" | grep -q 'Connected: yes' && echo 1 || echo 0); p=$(printf '%s' \"$i\" | grep -q 'Paired: yes' && echo 1 || echo 0); " +
      "t=$(printf '%s' \"$i\" | grep -q 'Trusted: yes' && echo 1 || echo 0); b=$(printf '%s' \"$i\" | sed -n 's/.*Battery Percentage:.*(\\([0-9]*\\)).*/\\1/p' | head -1); " +
      "printf '%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \"$mac\" \"$c\" \"$p\" \"$t\" \"$b\" \"$name\"; done"]
    stdout: StdioCollector {
      onStreamFinished: {
        var out = []
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var p = lines[i].split("\t")
          if (p.length < 6) continue
          out.push({ mac: p[0], connected: p[1] === "1", paired: p[2] === "1", trusted: p[3] === "1", battery: p[4] === "" ? -1 : parseInt(p[4]), name: p[5] })
        }
        out.sort(function(a, b) { return (b.connected - a.connected) || (b.paired - a.paired) })
        if (JSON.stringify(out) !== JSON.stringify(md.devices)) md.devices = out
      }
    }
  }
  function scan() {
    refreshWifi()
    if (!btProc.running) btProc.running = true
  }
  onLiveChanged: if (live) scan(); else { wifiMsg = ""; psk = ""; infoUuid = "" }
  Timer { interval: 6000; repeat: true; running: md.live; onTriggered: md.scan() }
  Timer { id: later; interval: 1500; onTriggered: { md.scan(); if (md.infoUuid !== "") md.details(md.infoUuid) } }
  function run(a) { Quickshell.execDetached(a); later.restart() }

  // ── Wi-Fi ──
  // сохранённая сеть поднимается своим профилем (пароль не нужен); новая — с паролем; если новая не поднялась,
  // созданный nmcli профиль удаляется, чтобы неверный пароль не запомнился как «известная сеть»
  function connectWifi(ssid, password) {
    var uuid = saved[ssid] || ""
    if (uuid && password && password.length)
      act("connecting " + ssid, ["sh", "-c", "nmcli con mod uuid \"$1\" wifi-sec.key-mgmt wpa-psk wifi-sec.psk \"$2\" && nmcli con up uuid \"$1\"", "sh", uuid, password])
    else if (uuid) act("connecting " + ssid, ["nmcli", "con", "up", "uuid", uuid])
    else if (password && password.length)
      act("connecting " + ssid, ["sh", "-c", "nmcli dev wifi connect \"$1\" password \"$2\" || { nmcli con delete id \"$1\" >/dev/null 2>&1; exit 1; }", "sh", ssid, password])
    else act("connecting " + ssid, ["nmcli", "dev", "wifi", "connect", ssid])
  }
  function connectHidden(ssid, password) {
    if (!ssid) return
    if (password) act("connecting " + ssid, ["sh", "-c", "nmcli dev wifi connect \"$1\" password \"$2\" hidden yes || { nmcli con delete id \"$1\" >/dev/null 2>&1; exit 1; }", "sh", ssid, password])
    else act("connecting " + ssid, ["nmcli", "dev", "wifi", "connect", ssid, "hidden", "yes"])
  }
  function disconnectWifi(ssid) {
    var uuid = saved[ssid] || ""
    act("disconnecting", uuid ? ["nmcli", "con", "down", "uuid", uuid] : ["nmcli", "con", "down", "id", ssid])
  }
  function rescan() { wifiMsg = "scanning…"; run(["sh", "-c", "nmcli dev wifi rescan; sleep 2"]); clearMsg.restart() }
  Timer { id: clearMsg; interval: 3000; onTriggered: if (md.wifiMsg === "scanning…") md.wifiMsg = "" }
  function details(uuid) { infoUuid = uuid; if (uuid && !infoProc.running) { infoProc.uuid = uuid; infoProc.running = true } }
  function closeDetails() { infoUuid = ""; info = ({}); psk = "" }
  function showPassword(uuid) { if (!pskProc.running) { pskProc.uuid = uuid; pskProc.running = true } }
  function forget(uuid) { psk = ""; act("forgetting", ["nmcli", "con", "delete", "uuid", uuid]) }
  function setAutoconnect(uuid, on) { act("saving", ["nmcli", "con", "mod", "uuid", uuid, "connection.autoconnect", on ? "yes" : "no"]) }
  // DNS: строка адресов через пробел / запятую (ipv4 и ipv6 вперемешку); пустая — DNS от роутера.
  // Активная сеть применяет его сразу (dev reapply), без переподключения.
  function setDns(uuid, servers) {
    var all = String(servers || "").split(/[\s,;]+/).filter(function(x) { return x !== "" })
    var v4 = all.filter(function(x) { return x.indexOf(":") === -1 }).join(","), v6 = all.filter(function(x) { return x.indexOf(":") !== -1 }).join(",")
    var auto = all.length === 0
    act("applying dns", ["sh", "-c", "nmcli con mod uuid \"$1\" ipv4.dns \"$2\" ipv4.ignore-auto-dns \"$4\" ipv6.dns \"$3\" ipv6.ignore-auto-dns \"$4\" && " +
      "if [ -n \"$5\" ] && nmcli -t -f GENERAL.STATE con show uuid \"$1\" | grep -q activated; then nmcli dev reapply \"$5\"; fi",
      "sh", uuid, v4, v6, auto ? "no" : "yes", wifiDev])
  }
  // текущий DNS профиля как строка и имя пресета ("" — свой)
  function dnsOf(i) {
    var a = []
    if (i && i["ipv4.dns"]) a = a.concat(String(i["ipv4.dns"]).split(",").filter(function(x) { return x !== "" }))
    if (i && i["ipv6.dns"]) a = a.concat(String(i["ipv6.dns"]).split(",").filter(function(x) { return x !== "" }))
    return a.join(" ")
  }
  function presetOf(i) {
    var cur = dnsOf(i)
    for (var k = 0; k < dnsPresets.length; k++) {
      var p = dnsPresets[k]
      if (cur === "" && p[1] === "") return p[0]
      if (cur !== "" && (cur === (p[1] + " " + p[2]).trim() || cur === p[1])) return p[0]
    }
    return ""
  }

  // ── Bluetooth ──
  // новое устройство: pair + trust + connect; известное — connect / disconnect
  function toggleDevice(d) {
    if (d.connected) run(["bluetoothctl", "disconnect", d.mac])
    else if (!d.paired) run(["sh", "-c", "bluetoothctl --timeout 20 pair \"$1\" && bluetoothctl trust \"$1\" && bluetoothctl connect \"$1\"", "sh", d.mac])
    else run(["bluetoothctl", "connect", d.mac])
  }
  function trustDevice(d, on) { run(["bluetoothctl", on ? "trust" : "untrust", d.mac]) }
  function forgetDevice(d) { run(["bluetoothctl", "remove", d.mac]) }
  function scanBt() { run(["sh", "-c", "timeout 8 bluetoothctl --timeout 8 scan on >/dev/null 2>&1"]) }

  // ── Звук ──
  function setSink(n) { if (n) Pipewire.preferredDefaultAudioSink = n }
  function setSource(n) { if (n) Pipewire.preferredDefaultAudioSource = n }
  function sinkName(n) { return n ? String(n.description || n.nickname || n.name || "") : "" }
}

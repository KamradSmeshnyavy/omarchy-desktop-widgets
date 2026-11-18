import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland

// Дашборд Retro CRT — «экран состояния» на весь экран, по его Retro/home/Home.qml (github.com/elifouts/Dotfiles,
// GPL-3.0; облик — retro/home-default.png). Открывается тем же dashboardOpen, когда dashStyle — crt; включается как
// трубка (CrtTube: черта по центру → раскрытие по вертикали). Сверху справа — день и дата со временем, по центру —
// имя машины капсом с чертой; строки QUICK KEYS (RUN / SETUP / SCREENS / TASKS / WIDGETS), LIVE LOAD (cpu, memory,
// temp, link — клетка загорается при > 85 %), SESSION (uptime, windows, workspaces, volume, battery, messages);
// строка о палитре; три рамки — SYSTEM, TASKS (окна, клик — к окну), NOW PLAYING. Любая клавиша или клик мимо —
// закрыть. Опрос системы — только пока открыт.
PanelWindow {
  id: win
  required property var host
  readonly property bool on: host.dashboardOpen && String(host.value("dashStyle")) === "crt"
  CrtPal { id: cp }

  property real t: 0
  visible: t > 0.001
  screen: host.focusedScreen
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  WlrLayershell.namespace: "omarchy-dashboard"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: on ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  onOnChanged: {
    if (on) { closing.stop(); opening.restart(); sysProbe.running = true; Hyprland.refreshToplevels() }
    else { opening.stop(); closing.restart() }
  }
  NumberAnimation { id: opening; target: win; property: "t"; to: 1; duration: 260; easing.type: Easing.OutCubic }
  NumberAnimation { id: closing; target: win; property: "t"; to: 0; duration: 180; easing.type: Easing.InCubic }
  function close() { host.dashboardOpen = false }
  function act(cmd) { close(); Quickshell.execDetached(cmd) }

  // ── данные ──
  SysStats { id: ss; live: win.on }
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: win.on; triggeredOnStart: true; onTriggered: win.now = new Date() }
  property var sys: ({})
  Process {
    id: sysProbe
    command: ["bash", "-c", "echo \"HOST=$(cat /etc/hostname 2>/dev/null || hostname)\"; . /etc/os-release 2>/dev/null; echo \"OS=$PRETTY_NAME\";" +
      "echo \"KERN=$(uname -r)\"; echo \"CPUM=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')\";" +
      "echo \"GPU=$(lspci 2>/dev/null | grep -m1 -E 'VGA|3D' | sed 's/.*: //; s/ (rev.*//')\";" +
      "awk '/^MemTotal/{print \"MEMT=\"$2} /^MemAvailable/{print \"MEMA=\"$2}' /proc/meminfo; echo \"UP=$(cut -d' ' -f1 /proc/uptime)\";" +
      "echo \"NET=$(nmcli -t -f STATE general 2>/dev/null)\"; echo \"MSG=$(ls ~/.local/state/omarchy/notifications/history 2>/dev/null | wc -l)\";" +
      "echo \"VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)\"; echo \"THEME=$(cat ~/.local/state/omarchy/current/theme.name 2>/dev/null)\""]
    stdout: StdioCollector {
      onStreamFinished: {
        var o = {}, lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) { var k = lines[i].indexOf("="); if (k > 0) o[lines[i].slice(0, k)] = lines[i].slice(k + 1) }
        win.sys = o
      }
    }
  }
  Timer { interval: 5000; repeat: true; running: win.on; onTriggered: if (!sysProbe.running) sysProbe.running = true }
  function uptime(sec) { var h = Math.floor(sec / 3600), m = Math.floor(sec % 3600 / 60); return h > 0 ? h + "h " + m + "m" : m + "m" }
  function gb(kb) { return (kb / 1048576).toFixed(1) }
  readonly property int volume: { var m = String(sys.VOL || "").match(/([\d.]+)/); return m ? Math.round(Number(m[1]) * 100) : 0 }
  readonly property bool muted: String(sys.VOL || "").indexOf("MUTED") !== -1
  readonly property bool online: String(sys.NET || "connected").indexOf("connected") === 0
  readonly property var battery: UPower.displayDevice
  readonly property bool hasBattery: !!battery && battery.isLaptopBattery
  readonly property string palette: {
    var n = String(sys.THEME || "")
    return n.indexOf("crt-") === 0 ? n.slice(4) : n.indexOf("dynamic") === 0 ? "wallpaper" : n
  }

  // ── части ──
  // во вложенных компонентах внешние id не видны — своя палитра
  component Cell: Rectangle {
    id: cell
    readonly property CrtPal pal: CrtPal {}
    property string big
    property string small
    property bool lit: false
    width: 104; height: 46
    color: lit ? cell.pal.accent : "transparent"
    border.width: 1; border.color: cell.pal.line
    Column {
      anchors.centerIn: parent
      CrtType { type: false; pal: cell.pal; anchors.horizontalCenter: parent.horizontalCenter; text: cell.big; color: cell.lit ? cell.pal.bg : cell.pal.fg; font.pixelSize: cell.pal.size + 1 }
      CrtType { type: false; pal: cell.pal; anchors.horizontalCenter: parent.horizontalCenter; text: cell.small; color: cell.lit ? cell.pal.bg : cell.pal.dim; font.pixelSize: cell.pal.size - 3 }
    }
  }
  component Read: Item {
    id: rd
    readonly property CrtPal pal: CrtPal {}
    property string k
    property string v
    width: parent ? parent.width : 300
    height: 20
    CrtType { pal: rd.pal; text: rd.k; height: rd.height; color: rd.pal.dim }
    CrtType { type: false; caps: false; pal: rd.pal; anchors.right: parent.right; width: rd.width - 100; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft; height: rd.height; text: rd.v; color: rd.pal.fg }
  }

  Item { anchors.fill: parent; focus: win.on; Keys.onPressed: function(e) { win.close(); e.accepted = true } }
  MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: win.close() }

  CrtTube {
    anchors.fill: parent
    pal: cp
    t: win.t
    Rectangle { anchors.fill: parent; color: cp.bg }
    MouseArea { anchors.fill: page; onClicked: {} }

    Item {
      id: page
      anchors.centerIn: parent
      width: Math.min(1180, parent.width - 80)
      height: Math.min(parent.height - 80, body.implicitHeight)

      Column {
        anchors.right: parent.right
        CrtType { pal: cp; type: false; anchors.right: parent.right; text: Qt.formatDate(win.now, "dddd") }
        CrtType { pal: cp; type: false; anchors.right: parent.right; text: Qt.formatDate(win.now, "dd MMM yy") + "   " + Qt.formatTime(win.now, "h:mm:ss AP") }
      }

      Column {
        id: body
        width: parent.width
        spacing: 18

        Item { width: 1; height: 8 }
        Column {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: 4
          CrtType { pal: cp; anchors.horizontalCenter: parent.horizontalCenter; text: win.sys.HOST || "sys"; font.pixelSize: 40; color: cp.accent }
          Rectangle { width: parent.width; height: 2; color: cp.accent }
        }

        Row {
          spacing: 18
          CrtType { pal: cp; width: 230; height: 26; text: "quick keys"; font.pixelSize: cp.size + 4 }
          Repeater {
            model: [["run", ["omarchy-apps"]], ["setup", ["omarchy-shell", "widgets", "togglePrefs"]],
              ["screens", ["omarchy-theme-bg-switcher"]], ["tasks", ["omarchy-shell", "widgets", "toggleOverview"]],
              ["widgets", ["omarchy-shell", "widgets", "toggleEdit"]]]
            CrtButton {
              required property var modelData
              required property int index
              pal: cp; label: modelData[0]; height: 26; width: 112; primary: index === 0
              onPressed: win.act(modelData[1])
            }
          }
        }

        Row {
          spacing: 18
          CrtType { pal: cp; width: 230; height: 46; text: "live load"; font.pixelSize: cp.size + 4 }
          Cell { big: Math.round(ss.cpu * 100) + "%"; small: "cpu"; lit: ss.cpu > 0.85 }
          Cell { big: Math.round(ss.mem * 100) + "%"; small: "memory"; lit: ss.mem > 0.85 }
          Cell { big: Math.round(ss.disk * 100) + "%"; small: "disk"; lit: ss.disk > 0.9 }
          Cell { visible: ss.temp > 0; big: Math.round(ss.temp * 100) + "°c"; small: "cpu temp"; lit: ss.temp > 0.85 }
          Cell { big: win.online ? "link" : "offline"; small: "link"; lit: !win.online }
        }

        Row {
          spacing: 18
          CrtType { pal: cp; width: 230; height: 46; text: "session"; font.pixelSize: cp.size + 4 }
          Cell { big: win.uptime(parseFloat(win.sys.UP || 0)); small: "uptime" }
          Cell { big: String(Hyprland.toplevels.values.length); small: "windows" }
          Cell { big: String(Hyprland.workspaces.values.filter(function(w) { return w.id > 0 }).length); small: "workspaces" }
          Cell { big: win.volume + "%"; small: win.muted ? "muted" : "volume"; lit: win.muted }
          Cell { visible: win.hasBattery; big: Math.round((win.battery ? win.battery.percentage : 0) * 100) + "%"; small: win.battery && win.battery.state === UPowerDeviceState.Charging ? "charging" : "battery" }
          Cell { big: String(win.sys.MSG || 0); small: "messages" }
        }

        CrtType { pal: cp; text: "this terminal is using the " + (win.palette || "phosphor") + " palette"; color: cp.dim; font.pixelSize: cp.size - 2 }

        Row {
          spacing: 18
          CrtBox {
            pal: cp
            width: (page.width - 36) / 3; height: 196
            title: "system"
            Column {
              x: 16; y: 18; width: parent.width - 32; spacing: 2
              Read { k: "os"; v: win.sys.OS || "" }
              Read { k: "kernel"; v: win.sys.KERN || "" }
              Read { k: "user"; v: Quickshell.env("USER") }
              Read { k: "cpu"; v: win.sys.CPUM || "" }
              Read { visible: !!win.sys.GPU; k: "gpu"; v: win.sys.GPU || "" }
              Read { k: "memory"; v: win.gb(Number(win.sys.MEMT || 0) - Number(win.sys.MEMA || 0)) + " / " + win.gb(Number(win.sys.MEMT || 0)) + " GB" }
            }
          }
          CrtBox {
            pal: cp
            width: (page.width - 36) / 3; height: 196
            title: "tasks"
            Column {
              x: 10; y: 16; width: parent.width - 20
              Repeater {
                model: Hyprland.toplevels.values.slice(0, 8)
                Rectangle {
                  id: line
                  required property var modelData
                  readonly property bool lit: !!modelData.activated
                  width: parent.width; height: 22
                  color: lr.containsMouse ? cp.low : "transparent"
                  CrtType { type: false; caps: false; pal: cp; x: 6; width: 26; height: parent.height; text: String(line.modelData.workspace ? line.modelData.workspace.id : "-"); color: cp.dim }
                  CrtType { type: false; caps: false; pal: cp; x: 32; width: parent.width - 32 - 120; height: parent.height; elide: Text.ElideRight; text: line.modelData.title || ""; color: line.lit ? cp.accent : cp.fg }
                  CrtType { type: false; pal: cp; anchors.right: parent.right; anchors.rightMargin: 6; width: 110; height: parent.height; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
                    text: String(line.modelData.lastIpcObject && line.modelData.lastIpcObject.class || line.modelData.appId || "").split(".").pop(); color: cp.dim }
                  MouseArea {
                    id: lr; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { Quickshell.execDetached(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ window = 'address:0x" + line.modelData.address + "' }))"]); win.close() }
                  }
                }
              }
            }
          }
          CrtBox {
            pal: cp
            width: (page.width - 36) / 3; height: 196
            title: "now playing"
            CrtMedia { x: 16; width: parent.width - 32; anchors.verticalCenter: parent.verticalCenter; pal: cp; player: win.host.player; live: win.on }
          }
        }
      }
    }
  }
}

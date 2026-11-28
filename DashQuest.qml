import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland

// Дашборд райса Quest — «экран статуса» ролевой игры (свой). Открывается dashboardOpen, когда dashStyle — quest.
// Окна-диалоги (QuestWin) раскрываются по очереди: ГЕРОЙ (портрет, LV — дни аптайма + 1, опыт — аптайм внутри суток),
// ХАРАКТЕРИСТИКИ (HP — батарея, MP — свободная память, СИЛА — свободный CPU, ЖАР — температура, ЗАПАС — свободный диск),
// ЭКИПИРОВКА (ОС, ядро, оконный менеджер, оболочка, процессор), ОТРЯД (открытые окна — клик к окну), БАРД (плеер),
// СУНДУКИ (терминал, файлы, браузер, снимок, Customizer) и СОХРАНЕНИЕ (блокировка, сон, перезагрузка, выключение —
// вторым нажатием). Клавиатура — KeyNav (стрелки / hjkl / Tab, Enter), Esc или клик мимо — закрыть.
PanelWindow {
  id: win
  required property var host
  readonly property bool on: host.dashboardOpen && String(host.value("dashStyle")) === "quest"
  QuestPal { id: qp }

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
    if (on) { closing.stop(); opening.restart(); sysProbe.running = true; Hyprland.refreshToplevels(); confirm = "" }
    else { opening.stop(); closing.restart() }
  }
  NumberAnimation { id: opening; target: win; property: "t"; to: 1; duration: 520; easing.type: Easing.Linear }
  NumberAnimation { id: closing; target: win; property: "t"; to: 0; duration: 180; easing.type: Easing.InCubic }
  function close() { host.dashboardOpen = false }
  function act(cmd) { close(); Quickshell.execDetached(cmd) }
  // i-е окно раскрывается после предыдущих, как диалоги в игре
  function grow(i) { return Math.max(0, Math.min(1, t * 4 - i * 0.45)) }

  // ── данные ──
  SysStats { id: ss; live: win.on }
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: win.on; triggeredOnStart: true; onTriggered: win.now = new Date() }
  property var sys: ({})
  Process {
    id: sysProbe
    command: ["bash", "-c", ". /etc/os-release 2>/dev/null; echo \"OS=$PRETTY_NAME\"; echo \"KERN=$(uname -r)\";" +
      "echo \"CPUM=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//; s/(R)//g; s/(TM)//g; s/ CPU//')\";" +
      "echo \"UP=$(cut -d' ' -f1 /proc/uptime)\"; echo \"FREE=$(df -B1G --output=avail / | tail -1 | tr -d ' ')\";" +
      "echo \"SHELL=$(basename \"$SHELL\")\"; echo \"HOST=$(cat /etc/hostname 2>/dev/null || hostname)\""]
    stdout: StdioCollector {
      onStreamFinished: {
        var o = {}, lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) { var k = lines[i].indexOf("="); if (k > 0) o[lines[i].slice(0, k)] = lines[i].slice(k + 1) }
        win.sys = o
      }
    }
  }
  Timer { interval: 10000; repeat: true; running: win.on; onTriggered: if (!sysProbe.running) sysProbe.running = true }
  readonly property real up: parseFloat(sys.UP || 0)
  readonly property int level: Math.floor(up / 86400) + 1
  readonly property var battery: UPower.displayDevice
  readonly property bool hasBattery: !!battery && battery.isLaptopBattery
  readonly property real hp: hasBattery ? battery.percentage : 1
  function dur(sec) { var d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60); return (d ? d + "д " : "") + h + "ч " + m + "м" }
  property string confirm: ""      // действие сохранения, ждущее второго нажатия

  // ── части (во вложенных компонентах внешние id не видны — своя палитра) ──
  component Label: Text {
    readonly property QuestPal pal: QuestPal {}
    color: pal.hi
    font.family: pal.font(8); font.pixelSize: pal.size(8)
  }
  component Meter: Row {
    id: meter
    readonly property QuestPal pal: QuestPal {}
    property string k
    property string note
    property real v: 0
    property color c: pal.hp
    property string val
    spacing: 12
    Text { width: 78; text: meter.k; color: meter.pal.hi; font.family: meter.pal.font(8); font.pixelSize: meter.pal.size(8); anchors.verticalCenter: parent.verticalCenter }
    Rectangle {
      width: 220; height: 12
      anchors.verticalCenter: parent.verticalCenter
      color: meter.pal.ink; border.width: 1; border.color: meter.pal.frame2; antialiasing: false
      Row {
        x: 2; y: 2; spacing: 2
        Repeater {
          model: 18
          Rectangle { required property int index; width: 10; height: 8; antialiasing: false; color: index < Math.round(Math.max(0, Math.min(1, meter.v)) * 18) ? meter.c : "transparent" }
        }
      }
    }
    Text { width: 90; text: meter.val; color: meter.pal.text; font.family: meter.pal.mono; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
    Text { text: meter.note; color: meter.pal.dim; font.family: meter.pal.body; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
  }
  component Btn: Item {
    id: btn
    readonly property QuestPal pal: QuestPal {}
    property string text
    property string icon: ""
    property bool hot: false
    signal hit()
    implicitWidth: bl.implicitWidth + (btn.icon !== "" ? 34 : 0) + 24
    implicitHeight: 34
    Rectangle {
      anchors.fill: parent
      color: ma.containsMouse || btn.hot ? btn.pal.alpha(btn.pal.frame, 0.16) : "transparent"
      border.width: btn.hot ? 2 : 0; border.color: btn.pal.red
      antialiasing: false
    }
    Row {
      anchors.centerIn: parent
      spacing: 10
      Image { visible: btn.icon !== ""; source: btn.icon !== "" ? btn.pal.sprite(btn.icon) : ""; smooth: false; width: 24; height: 24; fillMode: Image.PreserveAspectFit; anchors.verticalCenter: parent.verticalCenter }
      Text { id: bl; text: btn.text; color: btn.hot ? btn.pal.red : btn.pal.text; font.family: btn.pal.body; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: btn.hit() }
  }

  // фон: тёмная вуаль; клик мимо окон — закрыть
  Rectangle { anchors.fill: parent; color: "black"; opacity: 0.55 * Math.min(1, win.t * 2) }
  MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: win.close() }

  FocusScope {
    anchors.fill: parent
    focus: win.on
    Keys.onPressed: function(e) {
      if (e.key === Qt.Key_Escape) { win.close(); e.accepted = true; return }
      if (keyNav.handle(e)) e.accepted = true
    }

    Item {
      id: page
      anchors.centerIn: parent
      width: 1100; height: 700
      readonly property int colW: (width - 10) / 2

      // ── ГЕРОЙ ──
      QuestWin {
        id: hero
        pal: qp
        x: 0; y: 0; width: page.colW; height: 200
        transform: Scale { origin.y: hero.height / 2; yScale: win.grow(0) }
        MouseArea { anchors.fill: parent }
        Row {
          spacing: 22
          anchors.verticalCenter: parent.verticalCenter
          x: 6
          Rectangle {
            width: 120; height: 120
            color: qp.alpha(qp.ink, 0.5); border.width: 2; border.color: qp.frame2; antialiasing: false
            anchors.verticalCenter: parent.verticalCenter
            Image { anchors.centerIn: parent; source: qp.sprite("hero"); smooth: false; width: 96; height: 96 }
          }
          Column {
            spacing: 12
            anchors.verticalCenter: parent.verticalCenter
            Text { text: String(Quickshell.env("USER") || "hero").toUpperCase(); color: qp.text; font.family: qp.font(16); font.pixelSize: qp.size(16) }
            Text { text: "ВОИН " + String(win.sys.HOST || "").toUpperCase(); color: qp.dim; font.family: qp.font(8); font.pixelSize: qp.size(8) }
            Row {
              spacing: 14
              Label { text: "LV"; anchors.verticalCenter: parent.verticalCenter }
              Text { text: String(win.level); color: qp.text; font.family: qp.font(16); font.pixelSize: qp.size(16) }
            }
            Row {
              spacing: 10
              Label { text: "EXP"; anchors.verticalCenter: parent.verticalCenter }
              Rectangle {
                width: 180; height: 10; anchors.verticalCenter: parent.verticalCenter
                color: qp.ink; border.width: 1; border.color: qp.frame2; antialiasing: false
                Rectangle { x: 2; y: 2; height: 6; width: (parent.width - 4) * (win.up % 86400) / 86400; color: qp.hi; antialiasing: false }
              }
            }
            Text { text: "в пути " + win.dur(win.up); color: qp.dim; font.family: qp.body; font.pixelSize: 16 }
          }
        }
      }

      // ── ХАРАКТЕРИСТИКИ ──
      QuestWin {
        id: stats
        pal: qp
        x: page.colW + 10; y: 0; width: page.colW; height: 200
        transform: Scale { origin.y: stats.height / 2; yScale: win.grow(1) }
        MouseArea { anchors.fill: parent }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          x: 4
          spacing: 10
          Meter { k: "HP"; v: win.hp; c: win.hp < 0.2 ? qp.red : qp.hp; val: Math.round(win.hp * 100) + "/100"; note: win.hasBattery ? (win.battery.state === UPowerDeviceState.Charging ? "лечится" : "батарея") : "от сети" }
          Meter { k: "MP"; v: 1 - ss.mem; c: qp.mp; val: Math.round((1 - ss.mem) * 100) + "/100"; note: "память" }
          Meter { k: "СИЛА"; v: 1 - ss.cpu; c: qp.hi; val: Math.round((1 - ss.cpu) * 100) + "/100"; note: "процессор" }
          Meter { k: "ЖАР"; v: ss.temp; c: ss.temp > 0.8 ? qp.red : qp.alpha(qp.red, 0.8); val: Math.round(ss.temp * 100) + "°"; note: "температура" }
          Meter { k: "ЗАПАС"; v: 1 - ss.disk; c: qp.frame; val: (win.sys.FREE || "?") + " G"; note: "диск" }
        }
      }

      // ── ЭКИПИРОВКА ──
      QuestWin {
        id: gear
        pal: qp
        x: 0; y: 210; width: page.colW; height: 220
        transform: Scale { origin.y: gear.height / 2; yScale: win.grow(2) }
        MouseArea { anchors.fill: parent }
        Label { x: 4; y: 2; text: "ЭКИПИРОВКА" }
        Column {
          x: 4; y: 26
          width: parent.width - 8
          spacing: 6
          Repeater {
            model: [["Броня", win.sys.OS || ""], ["Шлем", win.sys.KERN || ""], ["Оружие", "Hyprland"],
                    ["Магия", win.sys.SHELL || ""], ["Амулет", win.sys.CPUM || ""]]
            Row {
              id: eq
              required property var modelData
              spacing: 14
              Image { source: qp.sprite("sword"); smooth: false; width: 16; height: 16; anchors.verticalCenter: parent.verticalCenter }
              Text { width: 110; text: eq.modelData[0]; color: qp.dim; font.family: qp.body; font.pixelSize: 17 }
              Text { width: gear.width - 180; elide: Text.ElideRight; text: eq.modelData[1]; color: qp.text; font.family: qp.body; font.pixelSize: 17 }
            }
          }
        }
      }

      // ── ОТРЯД (окна) ──
      QuestWin {
        id: party
        pal: qp
        x: page.colW + 10; y: 210; width: page.colW; height: 220
        transform: Scale { origin.y: party.height / 2; yScale: win.grow(3) }
        MouseArea { anchors.fill: parent }
        Label { x: 4; y: 2; text: "ОТРЯД · " + Hyprland.toplevels.values.length }
        Column {
          x: 0; y: 24
          width: parent.width
          Repeater {
            model: Hyprland.toplevels.values.slice(0, 6)
            Rectangle {
              id: line
              required property var modelData
              readonly property bool lit: !!modelData.activated
              width: parent.width; height: 28
              color: lr.containsMouse ? qp.alpha(qp.frame, 0.14) : "transparent"
              antialiasing: false
              Text { x: 6; width: 26; anchors.verticalCenter: parent.verticalCenter; text: String(line.modelData.workspace ? line.modelData.workspace.id : "-"); color: qp.hi; font.family: qp.font(8); font.pixelSize: qp.size(8) }
              Text { x: 34; width: parent.width - 40; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; text: line.modelData.title || ""; color: line.lit ? qp.hi : qp.text; font.family: qp.body; font.pixelSize: 16 }
              MouseArea {
                id: lr; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { Quickshell.execDetached(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ window = 'address:0x" + line.modelData.address + "' }))"]); win.close() }
              }
            }
          }
        }
      }

      // ── БАРД (плеер) ──
      QuestWin {
        id: bard
        pal: qp
        x: 0; y: 440; width: page.colW; height: 130
        transform: Scale { origin.y: bard.height / 2; yScale: win.grow(4) }
        readonly property var p: win.host.player
        MouseArea { anchors.fill: parent }
        Label { x: 4; y: 2; text: "БАРД" }
        Column {
          x: 4; y: 24
          width: parent.width - 8
          spacing: 6
          Text { width: parent.width; elide: Text.ElideRight; text: bard.p ? (bard.p.trackTitle || "без названия") : "тишина — бард отдыхает"; color: qp.text; font.family: qp.body; font.pixelSize: 18 }
          Text { width: parent.width; elide: Text.ElideRight; visible: !!bard.p; text: bard.p ? (bard.p.trackArtist || "") : ""; color: qp.dim; font.family: qp.body; font.pixelSize: 15 }
          Row {
            spacing: 6
            visible: !!bard.p
            Btn { text: "◀◀"; onHit: if (bard.p) bard.p.previous() }
            Btn { text: bard.p && bard.p.isPlaying ? "ПАУЗА" : "ИГРАТЬ"; onHit: if (bard.p) bard.p.togglePlaying() }
            Btn { text: "▶▶"; onHit: if (bard.p) bard.p.next() }
          }
        }
      }

      // ── СУНДУКИ (действия) ──
      QuestWin {
        id: chests
        pal: qp
        x: page.colW + 10; y: 440; width: page.colW; height: 130
        transform: Scale { origin.y: chests.height / 2; yScale: win.grow(5) }
        MouseArea { anchors.fill: parent }
        Label { x: 4; y: 2; text: "СУНДУКИ" }
        Flow {
          x: 0; y: 26
          width: parent.width
          spacing: 4
          Btn { text: "Терминал"; icon: "chest"; onHit: win.act(["omarchy-launch-terminal"]) }
          Btn { text: "Файлы"; icon: "chest"; onHit: win.act(["omarchy-launch-or-focus", "nautilus"]) }
          Btn { text: "Браузер"; icon: "chest"; onHit: win.act(["omarchy-launch-browser"]) }
          Btn { text: "Снимок"; icon: "star"; onHit: win.act(["omarchy-capture-screenshot"]) }
          Btn { text: "Облик"; icon: "potion"; onHit: win.act(["omarchy-shell", "shell", "toggle", "kamradsmeshnyavy.customizer"]) }
        }
      }

      // ── СОХРАНЕНИЕ / время ──
      QuestWin {
        id: save
        pal: qp
        x: 0; y: 580; width: page.width; height: 90
        transform: Scale { origin.y: save.height / 2; yScale: win.grow(6) }
        MouseArea { anchors.fill: parent }
        Column {
          x: 4
          anchors.verticalCenter: parent.verticalCenter
          spacing: 8
          Text { text: Qt.formatTime(win.now, "HH:mm"); color: qp.text; font.family: qp.font(16); font.pixelSize: qp.size(16) }
          Label { text: "ДЕНЬ " + Math.floor((win.now - new Date(win.now.getFullYear(), 0, 0)) / 86400000) + " · " + ["ВОСКРЕСЕНЬЕ", "ПОНЕДЕЛЬНИК", "ВТОРНИК", "СРЕДА", "ЧЕТВЕРГ", "ПЯТНИЦА", "СУББОТА"][win.now.getDay()] }
        }
        Row {
          anchors.right: parent.right; anchors.rightMargin: 4
          anchors.verticalCenter: parent.verticalCenter
          spacing: 6
          Repeater {
            model: [["lock", "Сохранить", ["omarchy-lock-screen"]], ["sleep", "Отдых", ["systemctl", "suspend"]],
                    ["reboot", "Заново", ["systemctl", "reboot"]], ["off", "Выход", ["systemctl", "poweroff"]]]
            Btn {
              required property var modelData
              text: win.confirm === modelData[0] ? "Точно?" : modelData[1]
              icon: modelData[0] === "off" ? "skull" : modelData[0] === "lock" ? "heart" : ""
              hot: win.confirm === modelData[0]
              // блокировка — сразу, остальное — вторым нажатием
              onHit: {
                if (modelData[0] === "lock" || win.confirm === modelData[0]) win.act(modelData[2])
                else win.confirm = modelData[0]
              }
            }
          }
        }
      }
    }

    KeyNav { id: keyNav; anchors.fill: parent; z: 999; scope: page; active: win.on; ring: qp.hi }
  }
}

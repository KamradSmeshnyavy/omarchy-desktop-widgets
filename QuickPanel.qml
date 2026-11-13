import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import "glyph"

// Quick — быстрые настройки из glyph-rice (quick/Quick.qml, GPL-3.0) вместо панели настроек (Super+M, settingsPanel:
// "quick" в widgets.json). Панель 470 у правого края, прижата к низу, выезжает справа: часы, пилюли Wi-Fi / Bluetooth
// (правый клик — список сетей / устройств), круглые плитки, слайдеры (залитое — белая пилюля, пустое — точки),
// режимы питания (если есть power-profiles-daemon), мини-плеер и последние уведомления. Окна за ней гаснут на 35 %.
// Плитки — команды Omarchy: тишина уведомлений, ночной свет, авиарежим (rfkill), не засыпать (omarchy-toggle-idle),
// микрофон, запись экрана (omarchy-capture-screenrecording; правый клик — область, звук, камера), режим чтения
// (Customizer) и пипетка (hyprpicker).
PanelWindow {
  id: root

  required property var host
  readonly property bool open: host.settingsOpen && host.value("settingsPanel") === "quick"
  function close() { host.settingsOpen = false }
  function pin() {}

  // открытый список: "wifi" | "bt" — под пилюлями (Picker), "rec" — под плитками (Rec), "" — ничего
  property string pick: ""
  onOpenChanged: {
    if (open) refresh()
    else pick = ""
  }

  property real t: open ? 1 : 0
  Behavior on t { NumberAnimation { duration: GTheme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: GTheme.glide } }

  visible: t > 0
  screen: host.focusedScreen
  anchors { left: true; right: true; top: true; bottom: true }
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  WlrLayershell.namespace: "omarchy-quick"

  // ── состояние системы ─────────────────────────────────────────────
  readonly property var wifi: Networking.devices.values.find(function(d) { return d.type === DeviceType.Wifi }) ?? null
  readonly property var net: wifi ? (wifi.networks.values.find(function(n) { return n.connected }) ?? null) : null
  readonly property var bt: Bluetooth.defaultAdapter
  readonly property var btDev: Bluetooth.devices.values.find(function(d) { return d.connected }) ?? null

  readonly property PwNode sink: Pipewire.defaultAudioSink
  readonly property PwNode source: Pipewire.defaultAudioSource
  PwObjectTracker { objects: [root.sink, root.source].filter(Boolean) }
  readonly property real vol: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool muted: !sink || !sink.audio || sink.audio.muted
  readonly property bool micOn: !!source && !!source.audio && !source.audio.muted

  readonly property var player: {
    var list = Mpris.players.values
    for (var i = 0; i < list.length; i++) if (list[i].isPlaying) return list[i]
    return list.length ? list[0] : null
  }

  property bool dnd: false
  property bool night: false
  property bool air: false
  property bool caffeine: false
  property bool rec: false
  property bool reading: false
  property real bri: 0.7
  property bool hasBri: false
  property var profiles: []      // power-profiles-daemon: ["power-saver", "balanced", "performance"]
  property string profile: ""
  property var notes: []

  readonly property string readingScript: Quickshell.env("HOME") + "/.config/omarchy/plugins/kamradsmeshnyavy.customizer/scripts/reading-mode.sh"
  readonly property string videosDir: "~/Videos"

  function sh(cmd, after) {
    var p = shProc.createObject(root, { command: ["sh", "-c", cmd] })
    p.exited.connect(function() { if (after) after(); p.destroy() })
    p.running = true
  }
  Component { id: shProc; Process {} }

  function refresh() {
    if (!probe.running) probe.running = true
    if (!history.running) history.running = true
  }
  // одна проверка на всё: ночной свет, авиарежим, не засыпать, запись, чтение, яркость, профили питания
  Process {
    id: probe
    command: ["sh", "-c",
      "l() { printf '%s\\n' \"$(\"$@\" 2>/dev/null | head -1)\"; }; " +
      "l omarchy-toggle-nightlight --status; " +
      "l sh -c \"rfkill -J | jq -c '[.rfkilldevices[] | .soft == \\\"blocked\\\"] | (length > 0 and all)'\"; " +
      "l sh -c 'omarchy-toggle-idle status | jq -c .enabled'; " +
      "l sh -c 'omarchy-capture-screenrecording --status >/dev/null 2>&1 && echo true'; " +
      "l \"$1\" status; " +
      "l brightnessctl -m; " +
      "l powerprofilesctl get; " +
      "l sh -c \"powerprofilesctl list | sed -n 's/^[* ] *\\\\([a-z-]*\\\\):$/\\\\1/p' | tr '\\\\n' ' '\"",
      "_", root.readingScript]
    stdout: StdioCollector {
      onStreamFinished: {
        var l = String(text || "").split("\n")
        try { root.night = JSON.parse(l[0] || "{}").enabled === true } catch (e) { root.night = false }
        root.air = (l[1] || "").trim() === "true"
        root.caffeine = (l[2] || "").trim() === "true"
        root.rec = (l[3] || "").trim() === "true"
        root.reading = (l[4] || "").trim() === "on"
        var b = (l[5] || "").trim().split(",")
        root.hasBri = b.length >= 5 && parseInt(b[4]) > 0
        if (root.hasBri) root.bri = parseInt(b[2]) / parseInt(b[4])
        root.profile = (l[6] || "").trim()
        var pl = (l[7] || "").trim()
        root.profiles = root.profile && pl ? pl.split(/\s+/).reverse() : []
      }
    }
  }
  Timer { interval: 2000; running: root.open; repeat: true; onTriggered: root.refresh() }

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/notifications.json"
    watchChanges: true
    printErrors: false
    onLoaded: { try { root.dnd = JSON.parse(text() || "{}").dnd === true } catch (e) { root.dnd = false } }
    onFileChanged: reload()
  }
  // последние уведомления — история Omarchy, свежие сверху
  Process {
    id: history
    command: ["python3", "-c",
      "import glob, json, os\n" +
      "p = os.path.expanduser('~/.local/state/omarchy/notifications/history/*.json')\n" +
      "out = []\n" +
      "for f in sorted(glob.glob(p), key=os.path.getmtime, reverse=True)[:8]:\n" +
      "  try:\n" +
      "    with open(f) as fh: out.append(json.load(fh))\n" +
      "  except Exception: pass\n" +
      "print(json.dumps(out))"]
    stdout: StdioCollector {
      onStreamFinished: { try { root.notes = JSON.parse(String(text || "[]")) || [] } catch (e) { root.notes = [] } }
    }
  }

  // настройки записи — ~/.config/omarchy/quick.json
  property var recCfg: ({ recArea: 0, recAudio: 0, recWebcam: false })
  FileView {
    id: quickCfg
    path: Quickshell.env("HOME") + "/.config/omarchy/quick.json"
    printErrors: false
    onLoaded: { try { root.recCfg = Object.assign({ recArea: 0, recAudio: 0, recWebcam: false }, JSON.parse(text() || "{}")) } catch (e) {} }
  }
  function setRec(key, v) {
    var o = Object.assign({}, recCfg)
    o[key] = v
    recCfg = o
    quickCfg.setText(JSON.stringify(o, null, 2) + "\n")
  }
  function recArgs() {
    var a = ["omarchy-capture-screenrecording"]
    if (rec) return a.concat(["--stop-recording"])
    if (recCfg.recArea === 1) a.push("--fullscreen")
    var au = Number(recCfg.recAudio) || 0
    if (au === 1 || au === 3) a.push("--with-desktop-audio")
    if (au === 2 || au === 3) a.push("--with-microphone-audio")
    if (recCfg.recWebcam === true) a.push("--with-webcam")
    return a
  }
  function toggleRec() {
    close()
    var a = recArgs()
    rec = !rec
    // после закрытия панели: иначе она попала бы в первый кадр, а slurp не видел бы экран
    recTimer.args = a
    recTimer.restart()
  }
  Timer { id: recTimer; property var args: []; interval: GTheme.t + 80; onTriggered: Quickshell.execDetached(args) }

  function setVol(v) {
    if (!sink || !sink.audio) return
    sink.audio.muted = false
    sink.audio.volume = Math.max(0, Math.min(1, v))
  }
  function setBri(v) {
    var pct = Math.round(Math.max(0.01, Math.min(1, v)) * 100)
    bri = pct / 100
    Quickshell.execDetached(["brightnessctl", "-q", "set", pct + "%"])
  }
  function ago(ms) {
    var s = Math.max(0, Math.round((Date.now() - ms) / 1000))
    return s < 60 ? "now" : s < 3600 ? Math.floor(s / 60) + "m" : s < 86400 ? Math.floor(s / 3600) + "h" : Math.floor(s / 86400) + "d"
  }

  SystemClock { id: clock; precision: SystemClock.Minutes }

  Rectangle {
    anchors.fill: parent
    color: "#000000"
    opacity: 0.35 * root.t
    MouseArea { anchors.fill: parent; onClicked: root.close() }
  }

  // холст макета 1920×1080
  readonly property real s: Math.min(width / 1920, height / 1080)
  Item {
    id: stage
    width: root.width / root.s
    height: root.height / root.s
    scale: root.s
    transformOrigin: Item.TopLeft

    Rectangle {
      id: panel
      anchors { right: parent.right; rightMargin: 14 - 24 * (1 - root.t); bottom: parent.bottom; bottomMargin: 14 }
      width: 470
      height: col.height + 44
      opacity: root.t
      radius: 36
      color: GTheme.s1
      border { width: 1; color: GTheme.s2 }
      focus: root.open
      Keys.onEscapePressed: root.close()
      MouseArea { anchors.fill: parent } // клик по панели не закрывает

      Column {
        id: col
        x: 22
        y: 22
        width: parent.width - 44
        spacing: 16

        Item {
          width: parent.width
          height: 54
          Row {
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            Num { anchors.verticalCenter: parent.verticalCenter; text: Qt.formatTime(clock.date, "HH:mm"); font.pixelSize: 44 }
            Lb { anchors.verticalCenter: parent.verticalCenter; text: Qt.locale("en_US").toString(clock.date, "ddd d MMM") }
          }
          Row {
            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
            spacing: 14
            Round { icon: "\u{F0493}"; onClicked: { root.close(); Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "kamradsmeshnyavy.customizer"]) } }
            Round { icon: "\u{F0425}"; onClicked: { root.close(); root.host.powerOpen = true } }
          }
        }

        Row {
          width: parent.width
          spacing: 12
          Pill {
            on: Networking.wifiEnabled
            icon: on ? "\u{F05A9}" : "\u{F05AA}"
            name: "Wi-Fi"
            sub: !on ? "off" : (Networking.connectivity === NetworkConnectivity.Portal ? "sign in · " : "") + (root.net ? root.net.name : "no network")
            picked: root.pick === "wifi"
            onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
            onMenu: root.pick = picked ? "" : "wifi"
          }
          Pill {
            on: root.bt ? root.bt.enabled : false
            icon: on ? "\u{F00AF}" : "\u{F00B2}"
            name: "Bluetooth"
            sub: !on ? "off" : (root.btDev ? root.btDev.name : "on")
            picked: root.pick === "bt"
            onClicked: if (root.bt) root.bt.enabled = !root.bt.enabled
            onMenu: root.pick = picked ? "" : "bt"
          }
        }

        Picker { width: parent.width; kind: root.pick; onTouched: root.pin() }

        Grid {
          width: parent.width
          columns: 4
          rowSpacing: 14
          Tile { icon: "\u{F009B}"; name: "dnd"; on: root.dnd; onClicked: { root.dnd = !root.dnd; Quickshell.execDetached(["omarchy-shell", "notifications", "toggleDnd"]) } }
          Tile { icon: "\u{F0594}"; name: "night"; on: root.night; onClicked: { root.night = !root.night; root.sh("omarchy-toggle-nightlight", root.refresh) } }
          Tile { icon: "\u{F001D}"; name: "airplane"; on: root.air; onClicked: { root.air = !root.air; root.sh(root.air ? "rfkill block all" : "rfkill unblock all", root.refresh) } }
          Tile { icon: "\u{F0176}"; name: "caffeine"; on: root.caffeine; onClicked: { root.caffeine = !root.caffeine; root.sh("omarchy-toggle-idle toggle", root.refresh) } }
          Tile { icon: on ? "\u{F036C}" : "\u{F036D}"; name: "mic"; on: root.micOn; onClicked: if (root.source && root.source.audio) root.source.audio.muted = !root.source.audio.muted }
          Tile { icon: "\u{F044A}"; name: "record"; on: root.rec; picked: root.pick === "rec"; onClicked: root.toggleRec(); onMenu: root.pick = picked ? "" : "rec" }
          Tile { icon: "\u{F0447}"; name: "reading"; on: root.reading; onClicked: { root.reading = !root.reading; root.sh("\"" + root.readingScript + "\" toggle", root.refresh) } }
          Tile { icon: "\u{F01E2}"; name: "picker"; on: false; onClicked: { root.close(); root.sh("sleep 0.4; hyprpicker -a") } }
        }

        Rec {
          width: parent.width
          visible: root.pick === "rec"
          st: root.recCfg
          recording: root.rec
          dir: root.videosDir
          onTouched: root.pin()
          onChanged: function(key, value) { root.setRec(key, value) }
          onStart: root.toggleRec()
        }

        Slider { icon: "\u{F00E0}"; visible: root.hasBri; value: root.bri; onMoved: function(v) { root.setBri(v) } }
        Slider { icon: root.muted ? "\u{F075F}" : "\u{F057E}"; value: root.muted ? 0 : root.vol; onMoved: function(v) { root.setVol(v) } }

        // режим питания (power-profiles-daemon): клетки, белая заливка переезжает к выбранной; засечки — сила
        Rectangle {
          id: modes
          visible: root.profiles.length > 1
          width: parent.width
          height: 54
          radius: 27
          color: GTheme.s2
          readonly property real cell: (width - 12) / Math.max(1, root.profiles.length)
          readonly property int at: root.profiles.indexOf(root.profile)
          Rectangle {
            visible: modes.at >= 0
            x: 6 + modes.cell * modes.at
            y: 6
            width: modes.cell
            height: parent.height - 12
            radius: height / 2
            color: GTheme.fg
            Behavior on x { NumberAnimation { duration: GTheme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: GTheme.glide } }
          }
          Repeater {
            model: root.profiles
            Item {
              id: mc
              required property int index
              required property string modelData
              readonly property bool on: modes.at === index
              x: 6 + modes.cell * index
              width: modes.cell
              height: modes.height
              Row {
                anchors.centerIn: parent
                spacing: 10
                Row {
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: 3
                  Repeater {
                    model: 3
                    Rectangle {
                      required property int index
                      anchors.bottom: parent.bottom
                      width: 4
                      height: 6 + index * 4
                      radius: 2
                      color: index <= mc.index ? (mc.on ? GTheme.ink : GTheme.fg) : (mc.on ? GTheme.mute : GTheme.s3)
                    }
                  }
                }
                Lb { anchors.verticalCenter: parent.verticalCenter; text: ({ "power-saver": "saver", "balanced": "balanced", "performance": "perf" })[mc.modelData] || mc.modelData; color: mc.on ? GTheme.ink : GTheme.grey }
              }
              TapHandler { onTapped: { root.profile = mc.modelData; root.sh("powerprofilesctl set " + mc.modelData, root.refresh) } }
              HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
          }
        }

        // мини-плеер
        Rectangle {
          visible: !!root.player
          width: parent.width
          height: 86
          radius: 30
          color: GTheme.s2
          Art { id: mart; x: 12; anchors.verticalCenter: parent.verticalCenter; width: 62; height: 62; step: 4; url: root.player ? root.player.trackArtUrl : "" }
          Column {
            anchors { left: mart.right; leftMargin: 16; right: mctl.left; rightMargin: 16; verticalCenter: parent.verticalCenter }
            Text { textFormat: Text.PlainText; width: parent.width; elide: Text.ElideRight; text: (root.player && root.player.trackTitle) || "Nothing on"; font { family: "Space Grotesk"; pixelSize: 16; weight: Font.DemiBold } color: GTheme.fg }
            Text { textFormat: Text.PlainText; width: parent.width; elide: Text.ElideRight; text: root.player ? root.player.trackArtist : ""; font { family: "Space Grotesk"; pixelSize: 13 } color: GTheme.grey }
          }
          Row {
            id: mctl
            anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
            spacing: 20
            Icon { anchors.verticalCenter: parent.verticalCenter; text: "\u{F04AE}"; font.pixelSize: 20; color: root.player && root.player.canGoPrevious ? GTheme.fg : GTheme.mute; TapHandler { onTapped: if (root.player) root.player.previous() } }
            Rectangle {
              width: 44; height: 44; radius: 22
              color: GTheme.accent
              Icon { anchors.centerIn: parent; text: root.player && root.player.isPlaying ? "\u{F03E4}" : "\u{F040A}"; color: "#ffffff"; font.pixelSize: 20 }
              TapHandler { onTapped: if (root.player) root.player.togglePlaying() }
            }
            Icon { anchors.verticalCenter: parent.verticalCenter; text: "\u{F04AD}"; font.pixelSize: 20; color: root.player && root.player.canGoNext ? GTheme.fg : GTheme.mute; TapHandler { onTapped: if (root.player) root.player.next() } }
          }
        }

        Item {
          width: parent.width
          height: 20
          Lb { x: 6; text: "notifications · " + root.notes.length }
          Lb {
            anchors.right: parent.right
            rightPadding: 6
            visible: root.notes.length > 0
            text: "replay"
            color: GTheme.fg
            TapHandler { onTapped: { root.close(); Quickshell.execDetached(["omarchy-shell", "notifications", "showHistory"]) } }
          }
        }

        // карточки уведомлений, свежие сверху; не влезли — листаются
        ListView {
          id: notesView
          width: parent.width
          height: Math.max(0, Math.min(contentHeight, stage.height - 28 - 44 - y))
          clip: true
          spacing: 10
          model: root.notes
          boundsBehavior: Flickable.StopAtBounds
          delegate: Rectangle {
            required property var modelData
            readonly property var n: modelData
            width: notesView.width
            height: body.height + 32
            radius: 26
            color: GTheme.s2
            border { width: n.urgency === 2 ? 1 : 0; color: GTheme.accent }
            Rectangle {
              x: 18
              y: 16
              width: 42
              height: 42
              radius: 21
              color: GTheme.s3
              Icon { anchors.centerIn: parent; text: "\u{F009A}"; visible: !nicon.visible }
              Image {
                id: nicon
                anchors.centerIn: parent
                width: 24
                height: 24
                visible: status === Image.Ready
                source: n.appIcon ? Quickshell.iconPath(n.appIcon, true) : ""
                sourceSize: Qt.size(24, 24)
                layer.enabled: true
                layer.effect: Dm { step: 2 }
              }
            }
            Column {
              id: body
              x: 74
              y: 16
              width: parent.width - x - 18
              Lb { width: parent.width; elide: Text.ElideRight; text: (n.app || "app") + " · " + root.ago(n.timestamp); px: 11 }
              Text { textFormat: Text.PlainText; width: parent.width; elide: Text.ElideRight; text: n.summary || ""; font { family: "Space Grotesk"; pixelSize: 15; weight: Font.DemiBold } color: GTheme.fg }
              Text {
                width: parent.width
                visible: !!n.body
                topPadding: 2
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                textFormat: Text.PlainText
                text: n.body || ""
                font { family: "Space Grotesk"; pixelSize: 14 }
                color: GTheme.grey
              }
            }
          }
        }
      }
    }
  }

  // круглая кнопка в шапке
  component Round: Rectangle {
    property string icon
    signal clicked
    width: 44
    height: 44
    radius: 22
    color: GTheme.s2
    Icon { anchors.centerIn: parent; text: parent.icon }
    TapHandler { onTapped: parent.clicked() }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
  }
  // пилюля: вкл — белая, текст чёрный. Правый клик — список сетей / устройств, шеврон показывает, открыт ли
  component Pill: Rectangle {
    id: pill
    property bool on
    property bool picked
    signal menu
    property string icon
    property string name
    property string sub
    signal clicked
    width: (col.width - 12) / 2
    height: 76
    radius: 38
    color: on ? GTheme.fg : GTheme.s2
    Behavior on color { ColorAnimation { duration: GTheme.t } }
    Rectangle {
      id: pi
      x: 12
      anchors.verticalCenter: parent.verticalCenter
      width: 52
      height: 52
      radius: 26
      color: pill.on ? GTheme.ink : GTheme.s3
      Icon { anchors.centerIn: parent; text: pill.icon; font.pixelSize: 22 }
    }
    Column {
      anchors { left: pi.right; leftMargin: 12; right: chev.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
      Text { text: pill.name; font { family: "Space Grotesk"; pixelSize: 16; weight: Font.DemiBold } color: pill.on ? GTheme.ink : GTheme.fg }
      Text {
        width: parent.width
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: pill.sub
        font { family: GTheme.mono; pixelSize: 11; letterSpacing: 0.9; capitalization: Font.AllUppercase }
        color: pill.on ? GTheme.ink : GTheme.fg
        opacity: 0.6
      }
    }
    Icon {
      id: chev
      anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
      text: "\u{F0140}"
      font.pixelSize: 18
      color: pill.on ? GTheme.ink : GTheme.fg
      opacity: pill.picked ? 1 : 0.4
      rotation: pill.picked ? 180 : 0
      Behavior on rotation { NumberAnimation { duration: GTheme.t; easing.type: Easing.BezierSpline; easing.bezierCurve: GTheme.glide } }
      TapHandler { onTapped: pill.menu() }
    }
    TapHandler { onTapped: pill.clicked() }
    TapHandler { acceptedButtons: Qt.RightButton; onTapped: pill.menu() }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
  }
  // круглая плитка 68: вкл — белый круг. Правый клик — menu (у record — настройки записи), открыто — подпись белая
  component Tile: Column {
    id: tile
    property bool on
    property bool picked
    signal menu
    property string icon
    property string name
    signal clicked
    width: col.width / 4
    spacing: 8
    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      width: 68
      height: 68
      radius: 34
      color: tile.on ? GTheme.fg : GTheme.s2
      Behavior on color { ColorAnimation { duration: GTheme.t } }
      Icon { anchors.centerIn: parent; text: tile.icon; font.pixelSize: 24; color: tile.on ? GTheme.ink : GTheme.fg }
      TapHandler { onTapped: tile.clicked() }
      TapHandler { acceptedButtons: Qt.RightButton; onTapped: tile.menu() }
      HoverHandler { cursorShape: Qt.PointingHandCursor }
    }
    Lb { anchors.horizontalCenter: parent.horizontalCenter; text: tile.name; px: 10; color: tile.picked ? GTheme.fg : GTheme.grey }
  }
  // слайдер: залитая часть — белая пилюля с иконкой, пустая — ряд точек
  component Slider: Rectangle {
    id: sl
    property real value
    property string icon
    signal moved(real v)
    readonly property real shown: area.pressed ? area.v : value
    width: col.width
    height: 54
    radius: 27
    color: GTheme.s2
    Row {
      x: 10
      anchors.verticalCenter: parent.verticalCenter
      spacing: 11 - 2.8
      Repeater {
        model: Math.max(0, Math.floor((sl.width - 20) / 11) + 1)
        Rectangle { width: 2.8; height: 2.8; radius: 1.4; color: GTheme.mute }
      }
    }
    Rectangle {
      width: Math.max(height, sl.width * sl.shown)
      height: parent.height
      radius: 27
      color: GTheme.fg
      Icon { x: 18; anchors.verticalCenter: parent.verticalCenter; text: sl.icon; font.pixelSize: 21; color: GTheme.ink }
    }
    Rectangle {
      anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
      width: val.width + 16
      height: val.height + 8
      radius: 10
      color: GTheme.s2
      Lb { id: val; anchors.centerIn: parent; text: Math.round(sl.shown * 100) }
    }
    MouseArea {
      id: area
      property real v
      property real wacc: 0
      anchors.fill: parent
      preventStealing: true
      function set(x) { v = Math.max(0, Math.min(1, x / width)); sl.moved(v) }
      onPressed: function(e) { set(e.x) }
      onPositionChanged: function(e) { set(e.x) }
      onWheel: function(e) {
        wacc += (e.inverted ? -1 : 1) * (e.angleDelta.y || -e.angleDelta.x) / 120 * 0.05 * (e.phase === Qt.NoScrollPhase ? 1 : 0.25)
        if (Math.abs(wacc) < 0.02) return
        sl.moved(Math.max(0, Math.min(1, sl.shown + wacc)))
        wacc = 0
      }
    }
  }
}

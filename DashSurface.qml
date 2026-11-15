import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Hub surface (dashStyle "surface", по мотивам surface-dots, snes19xx — hub/TopCards.qml и карточки hub/*; README
// разрешает брать со ссылкой; код свой): колонка 320 px из карточек цвета bgCard.
//   шапка — аватар, имя, кнопки «снимок» и «питание», под ними фишки cpu / ram;
//   кнопки — Wi-Fi (имя сети), Bluetooth, профиль питания (Auto), уведомления (Notify); включённые — залиты акцентом;
//            правый клик по Wi-Fi / Bluetooth — их панели; ниже — ползунки яркости и громкости;
//   плеер — обложка, название, исполнитель, время, волнистая полоса прогресса, назад / вперёд, круглая пауза;
//            фон — размытая обложка;
//   календарь — день недели, крупное число, погода; справа — месяц сеткой, сегодня — акцентом;
//   уведомления — счётчик, свернуть, Clear; последние из истории Omarchy.
// Цвета — роли его ThemeEngine из цветов темы (на темах surface-* совпадают с его).
Item {
  id: s

  required property var host
  property real rise: 1
  readonly property color fg: host.foreground
  readonly property color bg: host.background
  readonly property color acc: host.accent
  readonly property bool dark: 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b < 0.5
  function mix(a, b, k) { return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, 1) }
  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
  readonly property color card: dark ? mix(bg, fg, 0.06) : mix(bg, Qt.color("#000000"), 0.055)
  readonly property color item: dark ? mix(bg, fg, 0.14) : Qt.rgba(0, 0, 0, 0.05)
  readonly property color itemHover: dark ? mix(bg, fg, 0.19) : Qt.rgba(0, 0, 0, 0.08)
  readonly property color text2: mix(fg, bg, 0.38)
  readonly property color onAcc: dark ? "#232a2e" : "#f0ece6"
  readonly property color slider: dark ? mix(acc, Qt.color("#83c092"), 0.5) : mix(acc, Qt.color("#4f6b5b"), 0.5)
  readonly property color red: dark ? "#e67e80" : "#c74042"
  readonly property string font: Qt.fontFamilies().indexOf("Manrope") !== -1 ? "Manrope" : host.fontFamily
  readonly property string icons: host.iconFamily
  readonly property bool live: rise > 0.01

  implicitWidth: 320
  implicitHeight: col.implicitHeight

  opacity: Math.min(1, rise * 2)
  transform: Translate { y: (1 - Math.min(1, s.rise * 1.4)) * -14 }

  // ── состояние: сеть, Bluetooth, профиль, DND, яркость, уведомления, аватар ─────────────────────────────────
  property bool wifi: false
  property string ssid: ""
  property bool bt: false
  property string profile: ""
  property bool dnd: false
  property real bright: -1
  property var notes: []
  property bool notesOpen: true
  readonly property string avatar: {
    var a = String(host.value("dashAvatar") || "")
    if (!a) a = "~/.face"
    if (a.indexOf("~") === 0) a = Quickshell.env("HOME") + a.slice(1)
    return a.replace(/^file:\/\//, "")
  }
  Process {
    id: stateRead
    command: ["sh", "-c",
      "nmcli -t -f WIFI g 2>/dev/null | head -1; " +
      "nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep -v ':loopback' | head -1 | cut -d: -f1; " +
      "bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo on || echo off; " +
      "powerprofilesctl get 2>/dev/null || echo; " +
      "brightnessctl -m 2>/dev/null | head -1"]
    stdout: StdioCollector {
      onStreamFinished: {
        var l = String(text || "").split("\n")
        s.wifi = (l[0] || "").trim() === "enabled"
        s.ssid = (l[1] || "").trim()
        s.bt = (l[2] || "").trim() === "on"
        s.profile = (l[3] || "").trim()
        var b = (l[4] || "").split(",")
        s.bright = b.length > 3 ? Math.max(0, Math.min(1, parseFloat(b[3]) / 100)) : -1
      }
    }
  }
  Process {
    id: notesRead
    command: ["python3", "-c",
      "import glob, json, os\n" +
      "p = os.path.expanduser('~/.local/state/omarchy/notifications/history/*.json')\n" +
      "out = []\n" +
      "for f in sorted(glob.glob(p), key=os.path.getmtime, reverse=True)[:5]:\n" +
      "  try:\n" +
      "    with open(f) as fh: out.append(json.load(fh))\n" +
      "  except Exception: pass\n" +
      "print(json.dumps(out))"]
    stdout: StdioCollector { onStreamFinished: { try { s.notes = JSON.parse(String(text || "[]")) || [] } catch (e) { s.notes = [] } } }
  }
  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/notifications.json"
    watchChanges: true; printErrors: false
    onLoaded: { try { s.dnd = JSON.parse(text() || "{}").dnd === true } catch (e) { s.dnd = false } }
    onFileChanged: reload()
  }
  function refresh() {
    if (!stateRead.running) stateRead.running = true
    if (!notesRead.running) notesRead.running = true
  }
  onLiveChanged: if (live) refresh()
  Timer { interval: 3000; repeat: true; running: s.live; onTriggered: s.refresh() }
  function run(a) { Quickshell.execDetached(a); delayed.restart() }
  Timer { id: delayed; interval: 700; onTriggered: s.refresh() }

  PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property real vol: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool muted: !!(sink && sink.audio && sink.audio.muted)

  // ── общие детали ──────────────────────────────────────────────────────────────────────────────────────────────
  component Card: Rectangle {
    width: s.width
    radius: 16
    color: s.card
  }
  component Glyph: Text {
    font.family: s.icons
    color: s.fg
  }
  component IconBtn: Rectangle {
    id: ib
    property string icon
    property color tint: s.fg
    signal clicked()
    width: 26; height: 26; radius: 13
    color: ibh.hovered ? s.itemHover : "transparent"
    Glyph { anchors.centerIn: parent; text: ib.icon; color: ib.tint; font.pixelSize: 14 }
    HoverHandler { id: ibh; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: ib.clicked() }
  }
  component Chip: Rectangle {
    id: ch
    property string icon
    property string label
    height: 18; radius: 9
    width: chr.implicitWidth + 12
    color: s.item
    Row {
      id: chr
      anchors.centerIn: parent
      spacing: 3
      Glyph { text: ch.icon; font.pixelSize: 9; color: s.text2; anchors.verticalCenter: parent.verticalCenter }
      Text { text: ch.label; font.family: s.font; font.pixelSize: 9; font.weight: 700; color: s.fg; anchors.verticalCenter: parent.verticalCenter }
    }
  }
  // кнопка-переключатель 54 px: значок и подпись; включённая — залита акцентом, при нажатии скругление меньше
  component Toggle: Rectangle {
    id: tg
    property string icon
    property string label
    property bool on: false
    signal clicked()
    signal rightClicked()
    width: (s.width - 24 - 3 * 10) / 4
    height: 54
    radius: tap.pressed ? 10 : on ? 14 : 18
    color: on ? s.acc : tgh.hovered ? s.itemHover : s.item
    Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 180 } }
    Column {
      anchors.centerIn: parent
      spacing: 3
      Glyph { anchors.horizontalCenter: parent.horizontalCenter; text: tg.icon; font.pixelSize: 19; color: tg.on ? s.onAcc : s.fg }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        width: tg.width - 8
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: tg.label
        font.family: s.font; font.pixelSize: 8; font.weight: 600
        color: tg.on ? s.onAcc : s.text2
      }
    }
    HoverHandler { id: tgh; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; acceptedButtons: Qt.LeftButton | Qt.RightButton
      onTapped: function(ev, b) { if (b === Qt.RightButton) tg.rightClicked(); else tg.clicked() } }
  }
  // ползунок 24 px: дорожка цвета элемента, заливка цветом ползунков, значок внутри слева
  component Slider: Rectangle {
    id: sl
    property string icon
    property real value: 0
    signal moved(real v)
    width: s.width - 24
    height: 24
    radius: 12
    color: s.item
    Rectangle {
      width: Math.max(sl.height, sl.width * Math.max(0, Math.min(1, sl.value)))
      height: parent.height
      radius: parent.radius
      color: s.slider
      Behavior on width { enabled: !slm.pressed; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }
    Glyph { x: 9; anchors.verticalCenter: parent.verticalCenter; text: sl.icon; font.pixelSize: 13; color: s.onAcc }
    MouseArea {
      id: slm
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onPressed: function(m) { sl.moved(Math.max(0, Math.min(1, m.x / width))) }
      onPositionChanged: function(m) { if (pressed) sl.moved(Math.max(0, Math.min(1, m.x / width))) }
    }
    WheelHandler { onWheel: function(e) { sl.moved(Math.max(0, Math.min(1, sl.value + (e.angleDelta.y > 0 ? 0.05 : -0.05)))) } }
  }

  Column {
    id: col
    width: s.width
    spacing: 10

    // ── шапка ──────────────────────────────────────────────────────────────────────────────────────────────────
    Item {
      width: s.width
      height: 46
      Rectangle {
        id: face
        x: 4; anchors.verticalCenter: parent.verticalCenter
        width: 34; height: 34; radius: 17
        color: s.item
        clip: true
        Image {
          id: faceImg
          anchors.fill: parent
          source: s.avatar ? "file://" + s.avatar : ""
          fillMode: Image.PreserveAspectCrop
          sourceSize: Qt.size(96, 96)
          visible: false
          layer.enabled: true
        }
        Rectangle { id: faceMask; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
        MultiEffect { anchors.fill: parent; source: faceImg; visible: faceImg.status === Image.Ready; maskEnabled: true; maskSource: faceMask; maskThresholdMin: 0.5 }
        Text {
          anchors.centerIn: parent
          visible: faceImg.status !== Image.Ready
          text: (Quickshell.env("USER") || "u").charAt(0).toUpperCase()
          font.family: s.font; font.pixelSize: 15; font.weight: 800; color: s.acc
        }
      }
      Text {
        anchors.left: face.right; anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: Quickshell.env("USER") || "user"
        font.family: s.font; font.pixelSize: 15; font.weight: 800
        color: s.fg
      }
      Row {
        anchors.right: parent.right; anchors.rightMargin: 2
        y: 0
        spacing: 2
        IconBtn { icon: "\u{F019E}"; onClicked: { s.host.dashboardOpen = false; Quickshell.execDetached(["omarchy-capture-screenshot"]) } }
        IconBtn { icon: "\u{F0425}"; tint: s.red; onClicked: { s.host.dashboardOpen = false; s.host.powerOpen = true } }
      }
      Row {
        anchors.right: parent.right; anchors.rightMargin: 4
        anchors.bottom: parent.bottom
        spacing: 4
        Chip { icon: "\u{F061A}"; label: Math.round(s.host.cpu * 100) + "%" }
        Chip { icon: "\u{F035B}"; label: Math.round(s.host.mem * 100) + "%" }
      }
    }

    // ── кнопки и ползунки ──────────────────────────────────────────────────────────────────────────────────────
    Card {
      height: ctl.height + 24
      Column {
        id: ctl
        x: 12; y: 12
        spacing: 10
        Row {
          spacing: 10
          Toggle {
            icon: s.wifi ? "\u{F05A9}" : "\u{F05AA}"
            label: s.wifi ? (s.ssid || "Wi-Fi") : "Off"
            on: s.wifi
            onClicked: s.run(["nmcli", "radio", "wifi", s.wifi ? "off" : "on"])
            onRightClicked: { s.host.dashboardOpen = false; Quickshell.execDetached(["omarchy-shell", "omarchy.network", "toggle"]) }
          }
          Toggle {
            icon: s.bt ? "\u{F00AF}" : "\u{F00B2}"
            label: s.bt ? "On" : "Off"
            on: s.bt
            onClicked: s.run(["bluetoothctl", "power", s.bt ? "off" : "on"])
            onRightClicked: { s.host.dashboardOpen = false; Quickshell.execDetached(["omarchy-shell", "omarchy.bluetooth", "toggle"]) }
          }
          Toggle {
            icon: s.profile === "performance" ? "\u{F04C5}" : s.profile === "power-saver" ? "\u{F032A}" : "\u{F0EE1}"
            label: s.profile === "performance" ? "Max" : s.profile === "power-saver" ? "Save" : "Auto"
            on: s.profile === "performance"
            onClicked: s.run(["sh", "-c", "case $(powerprofilesctl get) in balanced) powerprofilesctl set performance;; performance) powerprofilesctl set power-saver;; *) powerprofilesctl set balanced;; esac"])
          }
          Toggle {
            icon: s.dnd ? "\u{F009B}" : "\u{F009A}"
            label: s.dnd ? "Silent" : "Notify"
            on: !s.dnd
            onClicked: { s.dnd = !s.dnd; Quickshell.execDetached(["omarchy-shell", "notifications", "toggleDnd"]) }
          }
        }
        Slider {
          visible: s.bright >= 0
          icon: "\u{F00DF}"
          value: s.bright
          onMoved: function(v) { s.bright = Math.max(0.02, v); Quickshell.execDetached(["brightnessctl", "-q", "set", Math.round(s.bright * 100) + "%"]) }
        }
        Slider {
          icon: s.muted ? "\u{F075F}" : "\u{F057E}"
          value: s.vol
          onMoved: function(v) { if (s.sink && s.sink.audio) { s.sink.audio.muted = false; s.sink.audio.volume = v } }
        }
      }
    }

    // ── плеер ──────────────────────────────────────────────────────────────────────────────────────────────────
    Card {
      id: media
      readonly property var p: s.host.player
      visible: !!p
      height: 92
      clip: true
      readonly property string art: p && p.trackArtUrl ? String(p.trackArtUrl) : ""
      Image {
        id: artBg
        anchors.fill: parent
        source: media.art
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(160, 160)
        visible: false
      }
      MultiEffect {
        anchors.fill: parent
        source: artBg
        visible: artBg.status === Image.Ready
        blurEnabled: true; blur: 1; blurMax: 48
        saturation: -0.2
        maskEnabled: true; maskSource: mediaMask; maskThresholdMin: 0.5
      }
      Rectangle { id: mediaMask; anchors.fill: parent; radius: 16; visible: false; layer.enabled: true }
      Rectangle { anchors.fill: parent; radius: 16; color: s.alpha(s.card, artBg.status === Image.Ready ? 0.62 : 0) }
      Rectangle {
        id: cover
        x: 10; anchors.verticalCenter: parent.verticalCenter
        width: 70; height: 70; radius: 10
        color: s.item
        Image { id: coverImg; anchors.fill: parent; source: media.art; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(140, 140); visible: false; layer.enabled: true }
        Rectangle { id: coverMask; anchors.fill: parent; radius: 10; visible: false; layer.enabled: true }
        MultiEffect { anchors.fill: parent; source: coverImg; visible: coverImg.status === Image.Ready; maskEnabled: true; maskSource: coverMask; maskThresholdMin: 0.5 }
        Glyph { anchors.centerIn: parent; visible: coverImg.status !== Image.Ready; text: "\u{F075A}"; font.pixelSize: 26; color: s.text2 }
      }
      Column {
        anchors.left: cover.right; anchors.leftMargin: 10
        anchors.right: playBtn.left; anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Text { width: parent.width; elide: Text.ElideRight; text: media.p ? media.p.trackTitle || "—" : ""; font.family: s.font; font.pixelSize: 13; font.weight: 700; color: s.fg }
        Text { width: parent.width; elide: Text.ElideRight; text: media.p ? media.p.trackArtist || "" : ""; font.family: s.font; font.pixelSize: 11; color: s.text2 }
        Text {
          function mmss(x) { x = Math.max(0, Math.floor(x || 0)); return Math.floor(x / 60) + ":" + ("0" + (x % 60)).slice(-2) }
          text: media.p ? mmss(media.p.position) + " / " + mmss(media.p.length) : ""
          font.family: s.font; font.pixelSize: 9; color: s.text2
        }
        Row {
          spacing: 6
          Glyph { text: "\u{F04AE}"; font.pixelSize: 11; color: s.text2; anchors.verticalCenter: parent.verticalCenter
            TapHandler { onTapped: if (media.p) media.p.previous() } HoverHandler { cursorShape: Qt.PointingHandCursor } }
          // волнистая полоса: пройденное — волной (бежит, пока играет), остаток — прямой линией
          Item {
            id: wave
            width: 96; height: 12
            anchors.verticalCenter: parent.verticalCenter
            readonly property real k: media.p && media.p.length > 0 ? Math.max(0, Math.min(1, media.p.position / media.p.length)) : 0
            property real phase: 0
            NumberAnimation on phase { from: 0; to: Math.PI * 2; duration: 1400; loops: Animation.Infinite; running: !!media.p && media.p.isPlaying && s.live }
            Shape {
              anchors.fill: parent
              preferredRendererType: Shape.CurveRenderer
              ShapePath {
                strokeColor: s.fg; strokeWidth: 2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: 0; startY: 6
                PathPolyline {
                  path: {
                    var pts = [], n = 24, w = wave.width * wave.k
                    for (var i = 0; i <= n; i++) { var x = w * i / n; pts.push(Qt.point(x, 6 + 2.6 * Math.sin(x / 4 - wave.phase))) }
                    return pts
                  }
                }
              }
              ShapePath {
                strokeColor: s.alpha(s.fg, 0.3); strokeWidth: 2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: wave.width * wave.k + 3; startY: 6
                PathLine { x: wave.width; y: 6 }
              }
            }
          }
          Glyph { text: "\u{F04AD}"; font.pixelSize: 11; color: s.text2; anchors.verticalCenter: parent.verticalCenter
            TapHandler { onTapped: if (media.p) media.p.next() } HoverHandler { cursorShape: Qt.PointingHandCursor } }
        }
      }
      Rectangle {
        id: playBtn
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 32; height: 32; radius: 16
        color: pbh.hovered ? s.itemHover : s.item
        Glyph { anchors.centerIn: parent; text: media.p && media.p.isPlaying ? "\u{F03E4}" : "\u{F040A}"; font.pixelSize: 15 }
        HoverHandler { id: pbh; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: if (media.p) media.p.togglePlaying() }
      }
    }

    // ── календарь и погода ─────────────────────────────────────────────────────────────────────────────────────
    Card {
      id: cal
      height: 106
      property date now: new Date()
      Timer { interval: 60000; repeat: true; running: s.live; onTriggered: cal.now = new Date() }
      readonly property var w: s.host.weather
      function wx(code) {
        var t = [[[0], "\u{F0599}", "Clear sky"], [[1, 2], "\u{F0595}", "Partly cloudy"], [[3], "\u{F0590}", "Overcast clouds"],
                 [[45, 48], "\u{F0591}", "Fog"], [[51, 53, 55, 56, 57], "\u{F0597}", "Drizzle"],
                 [[61, 63, 65, 66, 67, 80, 81, 82], "\u{F0596}", "Rain"], [[71, 73, 75, 77, 85, 86], "\u{F0598}", "Snow"],
                 [[95, 96, 99], "\u{F0593}", "Thunderstorm"]]
        for (var i = 0; i < t.length; i++) if (t[i][0].indexOf(code) !== -1) return t[i]
        return [[], "\u{F0590}", ""]
      }
      Column {
        x: 14; y: 10
        Text { text: Qt.formatDate(cal.now, "ddd").toUpperCase(); font.family: s.font; font.pixelSize: 15; font.weight: 600; color: s.fg }
        Text { text: Qt.formatDate(cal.now, "d"); font.family: s.font; font.pixelSize: 38; font.weight: 800; color: s.fg; lineHeight: 0.9 }
        Row {
          spacing: 4
          visible: !!cal.w && cal.w.error === undefined
          Glyph { text: cal.w ? cal.wx(cal.w.code)[1] : ""; font.pixelSize: 11; color: s.text2; anchors.verticalCenter: parent.verticalCenter }
          Text {
            text: cal.w && cal.w.temp !== undefined ? Math.round(cal.w.temp) + "° • " + cal.wx(cal.w.code)[2] : ""
            font.family: s.font; font.pixelSize: 9; color: s.text2
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
      Column {
        anchors.right: parent.right; anchors.rightMargin: 12
        y: 8
        spacing: 2
        Text { anchors.right: parent.right; text: Qt.formatDate(cal.now, "MMM").toUpperCase(); font.family: s.font; font.pixelSize: 9; font.weight: 800; color: s.fg; font.letterSpacing: 1 }
        Grid {
          id: grid
          columns: 7
          columnSpacing: 2; rowSpacing: 1
          readonly property var first: new Date(cal.now.getFullYear(), cal.now.getMonth(), 1)
          readonly property int lead: first.getDay()
          readonly property int days: new Date(cal.now.getFullYear(), cal.now.getMonth() + 1, 0).getDate()
          Repeater {
            model: ["S", "M", "T", "W", "T", "F", "S"]
            Text { required property var modelData; width: 13; horizontalAlignment: Text.AlignHCenter; text: modelData; font.family: s.font; font.pixelSize: 7; color: s.text2 }
          }
          Repeater {
            model: grid.lead + grid.days
            Rectangle {
              required property int index
              readonly property int d: index - grid.lead + 1
              readonly property bool today: d === cal.now.getDate()
              width: 13; height: 11; radius: 5
              color: today ? s.acc : "transparent"
              Text {
                anchors.centerIn: parent
                visible: parent.d > 0
                text: parent.d
                font.family: s.font; font.pixelSize: 7; font.weight: parent.today ? 800 : 500
                color: parent.today ? s.onAcc : s.fg
              }
            }
          }
        }
      }
    }

    // ── уведомления ────────────────────────────────────────────────────────────────────────────────────────────
    Card {
      height: nc.implicitHeight + 20
      Column {
        id: nc
        x: 12; y: 10
        width: parent.width - 24
        spacing: 8
        Item {
          width: parent.width; height: 22
          Text { anchors.verticalCenter: parent.verticalCenter; text: "Notifications"; font.family: s.font; font.pixelSize: 11; font.weight: 800; color: s.fg }
          Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Rectangle {
              width: 20; height: 20; radius: 10; color: s.item
              Text { anchors.centerIn: parent; text: s.notes.length; font.family: s.font; font.pixelSize: 9; font.weight: 700; color: s.fg }
            }
            Rectangle {
              width: 20; height: 20; radius: 10; color: chv.hovered ? s.itemHover : s.item
              Glyph { anchors.centerIn: parent; text: s.notesOpen ? "\u{F0143}" : "\u{F0140}"; font.pixelSize: 12 }
              HoverHandler { id: chv; cursorShape: Qt.PointingHandCursor }
              TapHandler { onTapped: s.notesOpen = !s.notesOpen }
            }
            Rectangle {
              width: 44; height: 20; radius: 10
              color: s.alpha(s.red, clr.hovered ? 0.3 : 0.18)
              Text { anchors.centerIn: parent; text: "Clear"; font.family: s.font; font.pixelSize: 9; font.weight: 700; color: s.red }
              HoverHandler { id: clr; cursorShape: Qt.PointingHandCursor }
              TapHandler {
                onTapped: {
                  s.notes = []
                  Quickshell.execDetached(["sh", "-c", "omarchy-shell notifications dismissAll >/dev/null 2>&1; omarchy-shell notifications clear >/dev/null 2>&1"])
                }
              }
            }
          }
        }
        Repeater {
          model: s.notesOpen ? s.notes.slice(0, 3) : []
          Rectangle {
            required property var modelData
            width: nc.width; height: 44; radius: 12
            color: s.item
            Rectangle {
              x: 10; anchors.verticalCenter: parent.verticalCenter
              width: 24; height: 24; radius: 12
              color: "transparent"; border.width: 1; border.color: s.alpha(s.fg, 0.25)
              Glyph { anchors.centerIn: parent; text: "\u{F02FC}"; font.pixelSize: 11; color: s.text2 }
            }
            Column {
              x: 44; anchors.verticalCenter: parent.verticalCenter
              width: parent.width - 54
              spacing: 1
              Text { width: parent.width; elide: Text.ElideRight; text: String(modelData.app || modelData.summary || "").toUpperCase(); font.family: s.font; font.pixelSize: 7; font.weight: 800; color: s.fg; font.letterSpacing: 0.5 }
              Text { width: parent.width; elide: Text.ElideRight; text: String(modelData.body || modelData.summary || "").replace(/<[^>]*>/g, ""); font.family: s.font; font.pixelSize: 10; color: s.fg }
            }
          }
        }
      }
    }
  }
}

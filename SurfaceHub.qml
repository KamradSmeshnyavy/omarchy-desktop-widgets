import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland

// Hub surface в Super+M (settingsPanel "surface"; по мотивам surface-dots, snes19xx — hub/HubWindow.qml, TopCards.qml,
// WifiPanel / BluetoothPanel; README разрешает брать со ссылкой; код свой). Колонка 320 px у правого края под баром
// (у нижнего бара — над ним), вместе с тем, что умела панель Super+M и Quick:
//   шапка — аватар, имя, аптайм; снимок, запись экрана, Customizer, питание; фишки cpu / ram;
//   переключатели — Wi-Fi, Bluetooth, профиль питания, уведомления / ночной свет, микрофон, «не засыпать», чтение;
//   ползунки — яркость, громкость, микрофон;
//   на месте плеера и календаря по запросу — списки Wi-Fi (подключиться), Bluetooth (подключить / отключить),
//   выходов звука (выбрать) — правый клик по плитке или клавиши i / t / a;
//   плеер, календарь с погодой, уведомления (Clear, свернуть, вся история).
// Клавиши, как у него: d / l — тёмная / светлая тема surface, n — свернуть уведомления, i / t / a — списки,
// s — Customizer, Esc — назад / закрыть.
PanelWindow {
  id: hub

  required property var host
  readonly property bool open: host.settingsOpen && host.value("settingsPanel") === "surface"
  property real k: open ? 1 : 0
  Behavior on k { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

  readonly property color fg: host.foreground
  readonly property color bg: host.background
  readonly property color acc: host.accent
  readonly property bool dark: 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b < 0.5
  function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1) }
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

  property string panel: ""            // "", "wifi", "bt", "audio"
  property bool notesOpen: true
  onOpenChanged: { if (open) { panel = ""; geo.refresh(); body.forceActiveFocus() } }

  SurfState { id: st; live: hub.open }
  // сохранённые сети и подключение с отчётом (общие с меню райсов): известной сети пароль не нужен
  MenuData { id: hd; live: hub.open && hub.panel === "wifi" }
  property string askFor: ""           // ssid, для которого открыто поле пароля

  // у нижнего бара — над ним, иначе — под ним (окно уважает зоны бара: Normal)
  BarGeom { id: geo }
  readonly property bool barBottom: geo.edge === "bottom"
  screen: host.focusedScreen
  visible: open || k > 0.01
  anchors { top: !barBottom; bottom: barBottom; right: true }
  margins { top: 6; bottom: 6; right: 6 }
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: 0
  implicitWidth: 320 + 24 + 24
  implicitHeight: body.implicitHeight + 24 + 24
  color: "transparent"
  WlrLayershell.namespace: "omarchy-settings"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

  // ── детали ──
  component Card: Rectangle { width: 320; radius: 16; color: hub.card }
  component Glyph: Text { font.family: hub.icons; color: hub.fg }
  component IconBtn: Rectangle {
    id: ib
    property string icon
    property color tint: hub.fg
    signal clicked()
    width: 26; height: 26; radius: 13
    color: ibh.hovered ? hub.itemHover : "transparent"
    Glyph { anchors.centerIn: parent; text: ib.icon; color: ib.tint; font.pixelSize: 14 }
    HoverHandler { id: ibh; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: ib.clicked() }
  }
  component Chip: Rectangle {
    id: ch
    property string icon
    property string label
    height: 18; radius: 9; width: chr.implicitWidth + 12
    color: hub.item
    Row {
      id: chr
      anchors.centerIn: parent; spacing: 3
      Glyph { text: ch.icon; font.pixelSize: 9; color: hub.text2; anchors.verticalCenter: parent.verticalCenter }
      Text { text: ch.label; font.family: hub.font; font.pixelSize: 9; font.weight: 700; color: hub.fg; anchors.verticalCenter: parent.verticalCenter }
    }
  }
  component Toggle: Rectangle {
    id: tg
    property string icon
    property string label
    property bool on: false
    signal clicked()
    signal rightClicked()
    width: (320 - 24 - 3 * 10) / 4
    height: 54
    radius: tap.pressed ? 10 : on ? 14 : 18
    color: on ? hub.acc : tgh.hovered ? hub.itemHover : hub.item
    Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on color { ColorAnimation { duration: 180 } }
    Column {
      anchors.centerIn: parent
      spacing: 3
      Glyph { anchors.horizontalCenter: parent.horizontalCenter; text: tg.icon; font.pixelSize: 19; color: tg.on ? hub.onAcc : hub.fg }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        width: tg.width - 8; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
        text: tg.label; font.family: hub.font; font.pixelSize: 8; font.weight: 600
        color: tg.on ? hub.onAcc : hub.text2
      }
    }
    HoverHandler { id: tgh; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; acceptedButtons: Qt.LeftButton | Qt.RightButton
      onTapped: function(ev, b) { if (b === Qt.RightButton) tg.rightClicked(); else tg.clicked() } }
  }
  component Slider: Rectangle {
    id: sl
    property string icon
    property real value: 0
    signal moved(real v)
    signal iconClicked()
    width: 320 - 24; height: 24; radius: 12
    color: hub.item
    Rectangle {
      width: Math.max(sl.height, sl.width * Math.max(0, Math.min(1, sl.value)))
      height: parent.height; radius: parent.radius
      color: hub.slider
      Behavior on width { enabled: !slm.pressed; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }
    MouseArea {
      id: slm
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onPressed: function(m) { if (m.x < 26) { sl.iconClicked(); return } sl.moved(Math.max(0, Math.min(1, m.x / width))) }
      onPositionChanged: function(m) { if (pressed && m.x >= 26) sl.moved(Math.max(0, Math.min(1, m.x / width))) }
    }
    Glyph { x: 9; anchors.verticalCenter: parent.verticalCenter; text: sl.icon; font.pixelSize: 13; color: hub.onAcc }
    WheelHandler { onWheel: function(e) { sl.moved(Math.max(0, Math.min(1, sl.value + (e.angleDelta.y > 0 ? 0.05 : -0.05)))) } }
  }
  component ListRow: Rectangle {
    id: lr
    property string icon
    property string title
    property string sub
    property bool on: false
    property string side: ""
    signal clicked()
    width: 320 - 24; height: 38; radius: 10
    color: on ? hub.alpha(hub.acc, hub.dark ? 0.55 : 0.4) : lrh.hovered ? hub.itemHover : "transparent"
    Glyph { x: 10; anchors.verticalCenter: parent.verticalCenter; text: lr.icon; font.pixelSize: 14; color: lr.on ? hub.onAcc : hub.fg }
    Column {
      x: 34; anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 34 - 70
      Text { width: parent.width; elide: Text.ElideRight; text: lr.title; font.family: hub.font; font.pixelSize: 10; font.weight: 700; color: lr.on ? hub.onAcc : hub.fg }
      Text { visible: lr.sub !== ""; width: parent.width; elide: Text.ElideRight; text: lr.sub; font.family: hub.font; font.pixelSize: 8; color: lr.on ? hub.onAcc : hub.text2 }
    }
    Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: lr.side; font.family: hub.font; font.pixelSize: 8; color: lr.on ? hub.onAcc : hub.text2 }
    HoverHandler { id: lrh; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: lr.clicked() }
  }

  // ── списки Wi-Fi ──
  property var nets: []
  Process {
    id: scan
    command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "auto"]
    stdout: StdioCollector {
      onStreamFinished: {
        var seen = {}, out = []
        String(text || "").split("\n").forEach(function(l) {
          var f = l.split(":")
          if (f.length < 4 || !f[1] || seen[f[1]]) return
          seen[f[1]] = true
          out.push({ on: f[0] === "*", ssid: f[1], signal: parseInt(f[2]) || 0, sec: f.slice(3).join(":") })
        })
        hub.nets = out.slice(0, 9)
      }
    }
  }
  onPanelChanged: { askFor = ""; if (panel === "wifi" && !scan.running) scan.running = true }

  Rectangle {
    id: frame
    x: 12; y: 12
    width: body.width + 24; height: body.implicitHeight + 24
    radius: 18
    color: hub.alpha(hub.bg, 0.97)
    border.width: 1
    border.color: hub.dark ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.1)
    opacity: hub.k
    transform: Translate { y: (1 - hub.k) * (hub.barBottom ? 16 : -16) }
    layer.enabled: true
    layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.6; shadowVerticalOffset: 4; shadowColor: Qt.rgba(0, 0, 0, 0.35) }

    FocusScope {
      id: body
      x: 12; y: 12
      width: 320
      implicitHeight: col.implicitHeight
      focus: true
      Keys.onPressed: e => {
        if (e.key === Qt.Key_Escape) { if (hub.panel !== "") hub.panel = ""; else hub.host.settingsOpen = false }
        else if (e.key === Qt.Key_D) st.setMode(true)
        else if (e.key === Qt.Key_L) st.setMode(false)
        else if (e.key === Qt.Key_N) hub.notesOpen = !hub.notesOpen
        else if (e.key === Qt.Key_I) hub.panel = hub.panel === "wifi" ? "" : "wifi"
        else if (e.key === Qt.Key_T) hub.panel = hub.panel === "bt" ? "" : "bt"
        else if (e.key === Qt.Key_A) hub.panel = hub.panel === "audio" ? "" : "audio"
        else if (e.key === Qt.Key_S) { hub.host.settingsOpen = false; Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "kamradsmeshnyavy.customizer"]) }
        else if (hubNav.handle(e)) {}
        else return
        e.accepted = true
      }

      // клавиатура: стрелки / Tab — по кнопкам, Enter — нажать (буквы у Hub свои, поэтому без hjkl)
      KeyNav { id: hubNav; anchors.fill: parent; z: 999; scope: parent; active: hub.open; vim: false; ring: hub.acc }

      Column {
        id: col
        width: 320
        spacing: 10

        // шапка
        Item {
          width: 320; height: 46
          Rectangle {
            id: face
            x: 4; anchors.verticalCenter: parent.verticalCenter
            width: 34; height: 34; radius: 17
            color: hub.item
            Image { id: faceImg; anchors.fill: parent; source: "file://" + Quickshell.env("HOME") + "/.face"; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(96, 96); visible: false; layer.enabled: true }
            Rectangle { id: faceMask; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
            MultiEffect { anchors.fill: parent; source: faceImg; visible: faceImg.status === Image.Ready; maskEnabled: true; maskSource: faceMask; maskThresholdMin: 0.5 }
            Text { anchors.centerIn: parent; visible: faceImg.status !== Image.Ready; text: (Quickshell.env("USER") || "u").charAt(0).toUpperCase(); font.family: hub.font; font.pixelSize: 15; font.weight: 800; color: hub.acc }
          }
          Column {
            anchors.left: face.right; anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            Text { text: Quickshell.env("USER") || "user"; font.family: hub.font; font.pixelSize: 14; font.weight: 800; color: hub.fg }
            Text { text: st.uptime ? "up " + st.uptime : ""; font.family: hub.font; font.pixelSize: 8; color: hub.text2 }
          }
          Row {
            anchors.right: parent.right; anchors.rightMargin: 2
            spacing: 2
            IconBtn { icon: "\u{F019E}"; onClicked: { hub.host.settingsOpen = false; Quickshell.execDetached(["omarchy-capture-screenshot"]) } }
            IconBtn { icon: st.rec ? "\u{F04DB}" : "\u{F044A}"; tint: st.rec ? hub.red : hub.fg
              onClicked: { hub.host.settingsOpen = false; Quickshell.execDetached(st.rec ? ["omarchy-capture-screenrecording", "--stop-recording"] : ["omarchy-capture-screenrecording"]) } }
            IconBtn { icon: "\u{F0493}"; onClicked: { hub.host.settingsOpen = false; Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "kamradsmeshnyavy.customizer"]) } }
            IconBtn { icon: "\u{F0425}"; tint: hub.red; onClicked: { hub.host.settingsOpen = false; hub.host.powerOpen = true } }
          }
          Row {
            anchors.right: parent.right; anchors.rightMargin: 4
            anchors.bottom: parent.bottom
            spacing: 4
            Chip { icon: "\u{F061A}"; label: Math.round(hub.host.cpu * 100) + "%" }
            Chip { icon: "\u{F035B}"; label: Math.round(hub.host.mem * 100) + "%" }
          }
        }

        // переключатели и ползунки
        Card {
          height: ctl.height + 24
          Column {
            id: ctl
            x: 12; y: 12
            spacing: 10
            Row {
              spacing: 10
              Toggle { icon: st.wifi ? "\u{F05A9}" : "\u{F05AA}"; label: st.wifi ? (st.ssid || "Wi-Fi") : "Off"; on: st.wifi
                onClicked: st.toggleWifi(); onRightClicked: hub.panel = hub.panel === "wifi" ? "" : "wifi" }
              Toggle { icon: st.bt ? "\u{F00AF}" : "\u{F00B2}"; label: st.bt ? "On" : "Off"; on: st.bt
                onClicked: st.toggleBt(); onRightClicked: hub.panel = hub.panel === "bt" ? "" : "bt" }
              Toggle {
                icon: st.profile === "performance" ? "\u{F04C5}" : st.profile === "power-saver" ? "\u{F032A}" : "\u{F0EE1}"
                label: st.profile === "performance" ? "Max" : st.profile === "power-saver" ? "Save" : "Auto"
                on: st.profile === "performance"
                onClicked: st.cycleProfile()
              }
              Toggle { icon: st.dnd ? "\u{F009B}" : "\u{F009A}"; label: st.dnd ? "Silent" : "Notify"; on: !st.dnd; onClicked: st.toggleDnd() }
            }
            Row {
              spacing: 10
              Toggle { icon: "\u{F0594}"; label: "Night"; on: st.night; onClicked: st.toggleNight() }
              Toggle { icon: st.micMuted ? "\u{F036D}" : "\u{F036C}"; label: st.micMuted ? "Muted" : "Mic"; on: !st.micMuted
                onClicked: st.toggleMic(); onRightClicked: hub.panel = hub.panel === "audio" ? "" : "audio" }
              Toggle { icon: "\u{F0176}"; label: "Awake"; on: st.caffeine; onClicked: st.toggleCaffeine() }
              Toggle { icon: "\u{F00BE}"; label: "Reading"; on: st.reading; onClicked: st.toggleReading() }
            }
            Slider { visible: st.bright >= 0; icon: "\u{F00DF}"; value: st.bright; onMoved: function(v) { st.setBright(v) } }
            Slider { icon: st.muted ? "\u{F075F}" : "\u{F057E}"; value: st.vol; onMoved: function(v) { st.setVol(v) }
              onIconClicked: if (st.sink && st.sink.audio) st.sink.audio.muted = !st.sink.audio.muted }
            Slider { icon: st.micMuted ? "\u{F036D}" : "\u{F036C}"; value: st.micVol; onMoved: function(v) { st.setMic(v) }; onIconClicked: st.toggleMic() }
          }
        }

        // списки: Wi-Fi, Bluetooth, звук
        Card {
          visible: hub.panel !== ""
          height: lists.implicitHeight + 20
          Column {
            id: lists
            x: 12; y: 10
            width: 320 - 24
            spacing: 4
            Item {
              width: parent.width; height: 24
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: hub.panel === "wifi" ? "Internet" : hub.panel === "bt" ? "Bluetooth" : "Sound output"
                font.family: hub.font; font.pixelSize: 12; font.weight: 800; color: hub.fg
              }
              Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                IconBtn { visible: hub.panel === "wifi"; icon: "\u{F0450}"; onClicked: if (!scan.running) scan.running = true }
                IconBtn { icon: "\u{F0156}"; onClicked: hub.panel = "" }
              }
            }
            Repeater {
              model: hub.panel === "wifi" ? hub.nets : []
              ListRow {
                required property var modelData
                icon: modelData.signal > 66 ? "\u{F0928}" : modelData.signal > 33 ? "\u{F0925}" : "\u{F091F}"
                title: modelData.ssid
                sub: modelData.on ? "Connected" : hd.saved[modelData.ssid] ? "Saved" : modelData.sec && modelData.sec !== "--" ? "Secured" : "Open"
                side: modelData.signal + "%"
                on: modelData.on
                onClicked: {
                  if (modelData.on) return
                  if (hd.saved[modelData.ssid] || !modelData.sec || modelData.sec === "--") hd.connectWifi(modelData.ssid, "")
                  else hub.askFor = hub.askFor === modelData.ssid ? "" : modelData.ssid
                }
              }
            }
            Rectangle {
              visible: hub.panel === "wifi" && hub.askFor !== ""
              width: 320 - 24; height: 38; radius: 10
              color: hub.itemHover; border.width: 1; border.color: hub.alpha(hub.acc, 0.8)
              property bool kbdNav: visible
              function kbdPress() { pwIn.forceActiveFocus() }
              TextInput {
                id: pwIn
                x: 12; width: parent.width - 24; anchors.verticalCenter: parent.verticalCenter; clip: true
                echoMode: TextInput.Password; color: hub.fg; font.family: hub.font; font.pixelSize: 11
                onVisibleChanged: if (visible) forceActiveFocus()
                Keys.onReturnPressed: { if (text.length) hd.connectWifi(hub.askFor, text); text = ""; hub.askFor = ""; body.forceActiveFocus() }
                Keys.onEscapePressed: { text = ""; hub.askFor = ""; body.forceActiveFocus() }
                Text { visible: !parent.text.length; text: "Password for " + hub.askFor; color: hub.text2; font: parent.font }
              }
            }
            Text {
              visible: hub.panel === "wifi" && hd.wifiMsg !== ""
              width: 320 - 24; wrapMode: Text.Wrap; leftPadding: 10
              text: hd.wifiMsg; color: hub.text2; font.family: hub.font; font.pixelSize: 9
            }
            Repeater {
              model: hub.panel === "bt" ? Bluetooth.devices.values.filter(function(d) { return d.paired || d.connected }) : []
              ListRow {
                required property var modelData
                icon: "\u{F00AF}"
                title: modelData.name || modelData.address
                sub: modelData.connected ? "Connected" : "Paired"
                side: modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%" : ""
                on: modelData.connected
                onClicked: modelData.connected = !modelData.connected
              }
            }
            Repeater {
              model: hub.panel === "audio" ? Pipewire.nodes.values.filter(function(n) { return n.isSink && !n.isStream && n.audio }) : []
              ListRow {
                required property var modelData
                icon: "\u{F04C3}"
                title: modelData.description || modelData.nickname || modelData.name
                on: Pipewire.defaultAudioSink === modelData
                onClicked: Pipewire.preferredDefaultAudioSink = modelData
              }
            }
            ListRow {
              visible: hub.panel === "wifi" || hub.panel === "bt"
              icon: "\u{F0493}"
              title: "Open advanced settings"
              onClicked: { hub.host.settingsOpen = false; Quickshell.execDetached(["omarchy-shell", hub.panel === "wifi" ? "omarchy.network" : "omarchy.bluetooth", "toggle"]) }
            }
          }
        }

        // плеер
        Card {
          id: media
          readonly property var p: hub.host.player
          visible: !!p && hub.panel === ""
          height: 92
          clip: true
          readonly property string art: p && p.trackArtUrl ? String(p.trackArtUrl) : ""
          Image { id: artBg; anchors.fill: parent; source: media.art; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(160, 160); visible: false }
          MultiEffect { anchors.fill: parent; source: artBg; visible: artBg.status === Image.Ready; blurEnabled: true; blur: 1; blurMax: 48; saturation: -0.2
            maskEnabled: true; maskSource: mediaMask; maskThresholdMin: 0.5 }
          Rectangle { id: mediaMask; anchors.fill: parent; radius: 16; visible: false; layer.enabled: true }
          Rectangle { anchors.fill: parent; radius: 16; color: hub.alpha(hub.card, artBg.status === Image.Ready ? 0.62 : 0) }
          Rectangle {
            id: cover
            x: 10; anchors.verticalCenter: parent.verticalCenter
            width: 70; height: 70; radius: 10; color: hub.item
            Image { id: coverImg; anchors.fill: parent; source: media.art; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(140, 140); visible: false; layer.enabled: true }
            Rectangle { id: coverMask; anchors.fill: parent; radius: 10; visible: false; layer.enabled: true }
            MultiEffect { anchors.fill: parent; source: coverImg; visible: coverImg.status === Image.Ready; maskEnabled: true; maskSource: coverMask; maskThresholdMin: 0.5 }
            Glyph { anchors.centerIn: parent; visible: coverImg.status !== Image.Ready; text: "\u{F075A}"; font.pixelSize: 26; color: hub.text2 }
          }
          Column {
            anchors.left: cover.right; anchors.leftMargin: 10
            anchors.right: playBtn.left; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text { width: parent.width; elide: Text.ElideRight; text: media.p ? media.p.trackTitle || "—" : ""; font.family: hub.font; font.pixelSize: 13; font.weight: 700; color: hub.fg }
            Text { width: parent.width; elide: Text.ElideRight; text: media.p ? media.p.trackArtist || "" : ""; font.family: hub.font; font.pixelSize: 11; color: hub.text2 }
            Text {
              function mmss(x) { x = Math.max(0, Math.floor(x || 0)); return Math.floor(x / 60) + ":" + ("0" + (x % 60)).slice(-2) }
              text: media.p ? mmss(media.p.position) + " / " + mmss(media.p.length) : ""
              font.family: hub.font; font.pixelSize: 9; color: hub.text2
            }
            Row {
              spacing: 6
              Glyph { text: "\u{F04AE}"; font.pixelSize: 11; color: hub.text2; anchors.verticalCenter: parent.verticalCenter
                TapHandler { onTapped: if (media.p) media.p.previous() } HoverHandler { cursorShape: Qt.PointingHandCursor } }
              Item {
                id: wave
                width: 96; height: 12
                anchors.verticalCenter: parent.verticalCenter
                readonly property real kk: media.p && media.p.length > 0 ? Math.max(0, Math.min(1, media.p.position / media.p.length)) : 0
                property real phase: 0
                NumberAnimation on phase { from: 0; to: Math.PI * 2; duration: 1400; loops: Animation.Infinite; running: !!media.p && media.p.isPlaying && hub.open }
                Shape {
                  anchors.fill: parent
                  preferredRendererType: Shape.CurveRenderer
                  ShapePath {
                    strokeColor: hub.fg; strokeWidth: 2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    startX: 0; startY: 6
                    PathPolyline { path: { var pts = [], n = 24, w = wave.width * wave.kk; for (var i = 0; i <= n; i++) { var x = w * i / n; pts.push(Qt.point(x, 6 + 2.6 * Math.sin(x / 4 - wave.phase))) } return pts } }
                  }
                  ShapePath {
                    strokeColor: hub.alpha(hub.fg, 0.3); strokeWidth: 2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    startX: wave.width * wave.kk + 3; startY: 6
                    PathLine { x: wave.width; y: 6 }
                  }
                }
              }
              Glyph { text: "\u{F04AD}"; font.pixelSize: 11; color: hub.text2; anchors.verticalCenter: parent.verticalCenter
                TapHandler { onTapped: if (media.p) media.p.next() } HoverHandler { cursorShape: Qt.PointingHandCursor } }
            }
          }
          Rectangle {
            id: playBtn
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 32; height: 32; radius: 16
            color: pbh.hovered ? hub.itemHover : hub.item
            Glyph { anchors.centerIn: parent; text: media.p && media.p.isPlaying ? "\u{F03E4}" : "\u{F040A}"; font.pixelSize: 15 }
            HoverHandler { id: pbh; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: if (media.p) media.p.togglePlaying() }
          }
        }

        // календарь и погода
        SurfCalendar {
          visible: hub.panel === ""
          width: 320; height: 106
          host: hub.host
          live: hub.open
          card: hub.card; fg: hub.fg; text2: hub.text2; acc: hub.acc; onAcc: hub.onAcc; font: hub.font; icons: hub.icons
        }

        // уведомления
        Card {
          height: nc.implicitHeight + 20
          Column {
            id: nc
            x: 12; y: 10
            width: 320 - 24
            spacing: 8
            Item {
              width: parent.width; height: 22
              Text { anchors.verticalCenter: parent.verticalCenter; text: "Notifications"; font.family: hub.font; font.pixelSize: 11; font.weight: 800; color: hub.fg }
              Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Rectangle {
                  width: 20; height: 20; radius: 10; color: hub.item
                  Text { anchors.centerIn: parent; text: st.notes.length; font.family: hub.font; font.pixelSize: 9; font.weight: 700; color: hub.fg }
                  TapHandler { onTapped: { hub.host.settingsOpen = false; Quickshell.execDetached(["omarchy-shell", "notifications", "showHistory"]) } }
                  HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
                Rectangle {
                  width: 20; height: 20; radius: 10; color: chv.hovered ? hub.itemHover : hub.item
                  Glyph { anchors.centerIn: parent; text: hub.notesOpen ? "\u{F0143}" : "\u{F0140}"; font.pixelSize: 12 }
                  HoverHandler { id: chv; cursorShape: Qt.PointingHandCursor }
                  TapHandler { onTapped: hub.notesOpen = !hub.notesOpen }
                }
                Rectangle {
                  width: 44; height: 20; radius: 10
                  color: hub.alpha(hub.red, clr.hovered ? 0.3 : 0.18)
                  Text { anchors.centerIn: parent; text: "Clear"; font.family: hub.font; font.pixelSize: 9; font.weight: 700; color: hub.red }
                  HoverHandler { id: clr; cursorShape: Qt.PointingHandCursor }
                  TapHandler { onTapped: st.clearNotes() }
                }
              }
            }
            Repeater {
              model: hub.notesOpen ? st.notes.slice(0, hub.panel === "" ? 3 : 2) : []
              Rectangle {
                required property var modelData
                width: nc.width; height: 44; radius: 12
                color: hub.item
                Rectangle {
                  x: 10; anchors.verticalCenter: parent.verticalCenter
                  width: 24; height: 24; radius: 12
                  color: "transparent"; border.width: 1; border.color: hub.alpha(hub.fg, 0.25)
                  Glyph { anchors.centerIn: parent; text: "\u{F02FC}"; font.pixelSize: 11; color: hub.text2 }
                }
                Column {
                  x: 44; anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - 54
                  spacing: 1
                  Text { width: parent.width; elide: Text.ElideRight; text: String(modelData.app || modelData.summary || "").toUpperCase(); font.family: hub.font; font.pixelSize: 7; font.weight: 800; color: hub.fg; font.letterSpacing: 0.5 }
                  Text { width: parent.width; elide: Text.ElideRight; text: String(modelData.body || modelData.summary || "").replace(/<[^>]*>/g, ""); font.family: hub.font; font.pixelSize: 10; color: hub.fg }
                }
              }
            }
          }
        }
      }
    }
  }
}

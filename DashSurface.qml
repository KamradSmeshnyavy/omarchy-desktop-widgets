import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell

// Дашборд surface (dashStyle "surface", по мотивам Hub режима таскбара surface-dots, snes19xx — hub/TaskCards.qml,
// MediaCard, CalendarWeatherCard, ButtonsSlidersCard, Events, NotificationsCard; README разрешает брать со ссылкой; код
// свой). Широкая панель 520 px в две колонки (компактный Hub — в Super+M, SurfaceHub.qml):
//   шапка — аватар и имя; монитор системы, Customizer, снимок, питание;
//   плеер во всю ширину — обложка, название, исполнитель, время, длинная волнистая полоса, назад / вперёд, пауза;
//     фон — размытая обложка, подкрашенная её цветами;
//   слева — большой календарь с погодой; справа — столбик кнопок (Wi-Fi, Bluetooth, профиль, уведомления) и два
//     высоких вертикальных ползунка (яркость, громкость);
//   «Upcoming» — напоминания omarchy-reminder (ближайшее, время и сколько осталось);
//   уведомления — счётчик, развернуть, Clear.
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
  property bool notesOpen: false

  SurfState { id: st; live: s.live }

  implicitWidth: 520
  implicitHeight: col.implicitHeight

  opacity: Math.min(1, rise * 2)
  transform: Translate { y: (1 - Math.min(1, s.rise * 1.4)) * 14 }

  component Card: Rectangle { width: s.width; radius: 10; color: s.card }
  component Glyph: Text { font.family: s.icons; color: s.fg }
  component IconBtn: Rectangle {
    id: ib
    property string icon
    property color tint: s.fg
    property color fill: s.item
    signal clicked()
    width: 26; height: 26; radius: 13
    color: ibh.hovered ? s.itemHover : fill
    Glyph { anchors.centerIn: parent; text: ib.icon; color: ib.tint; font.pixelSize: 13 }
    HoverHandler { id: ibh; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: ib.clicked() }
  }
  // кнопка столбика: значок и подпись, включённая — акцентом
  component VBtn: Rectangle {
    id: vb
    property string icon
    property string label
    property bool on: false
    signal clicked()
    signal rightClicked()
    width: 64; height: 32
    radius: on ? 8 : 10
    color: on ? s.alpha(s.acc, 0.85) : vbh.hovered ? s.itemHover : s.item
    Behavior on color { ColorAnimation { duration: 160 } }
    Column {
      anchors.centerIn: parent
      Glyph { anchors.horizontalCenter: parent.horizontalCenter; text: vb.icon; font.pixelSize: 13; color: vb.on ? s.onAcc : s.fg }
      Text { anchors.horizontalCenter: parent.horizontalCenter; width: vb.width - 6; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
        text: vb.label; font.family: s.font; font.pixelSize: 6; font.weight: 600; color: vb.on ? s.onAcc : s.text2 }
    }
    HoverHandler { id: vbh; cursorShape: Qt.PointingHandCursor }
    TapHandler { acceptedButtons: Qt.LeftButton | Qt.RightButton
      onTapped: function(ev, b) { if (b === Qt.RightButton) vb.rightClicked(); else vb.clicked() } }
  }
  // высокий вертикальный ползунок: заливка снизу, значок внизу
  component VSlider: Rectangle {
    id: vs
    property string icon
    property real value: 0
    signal moved(real v)
    width: 30; radius: 15
    color: s.item
    Rectangle {
      anchors.bottom: parent.bottom
      width: parent.width; radius: parent.radius
      height: Math.max(vs.width, vs.height * Math.max(0, Math.min(1, vs.value)))
      color: s.slider
      Behavior on height { enabled: !vsm.pressed; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }
    Glyph { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 8; text: vs.icon; font.pixelSize: 13; color: s.onAcc }
    MouseArea {
      id: vsm
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onPressed: function(m) { vs.moved(Math.max(0, Math.min(1, 1 - m.y / height))) }
      onPositionChanged: function(m) { if (pressed) vs.moved(Math.max(0, Math.min(1, 1 - m.y / height))) }
    }
    WheelHandler { onWheel: function(e) { vs.moved(Math.max(0, Math.min(1, vs.value + (e.angleDelta.y > 0 ? 0.05 : -0.05)))) } }
  }

  Column {
    id: col
    width: s.width
    spacing: 10

    // шапка
    Item {
      width: s.width; height: 34
      Rectangle {
        id: face
        x: 2; anchors.verticalCenter: parent.verticalCenter
        width: 26; height: 26; radius: 13
        color: s.item
        Image { id: faceImg; anchors.fill: parent; source: "file://" + Quickshell.env("HOME") + "/.face"; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(80, 80); visible: false; layer.enabled: true }
        Rectangle { id: faceMask; anchors.fill: parent; radius: width / 2; visible: false; layer.enabled: true }
        MultiEffect { anchors.fill: parent; source: faceImg; visible: faceImg.status === Image.Ready; maskEnabled: true; maskSource: faceMask; maskThresholdMin: 0.5 }
        Text { anchors.centerIn: parent; visible: faceImg.status !== Image.Ready; text: (Quickshell.env("USER") || "u").charAt(0).toUpperCase(); font.family: s.font; font.pixelSize: 12; font.weight: 800; color: s.acc }
      }
      Text {
        anchors.left: face.right; anchors.leftMargin: 9; anchors.verticalCenter: parent.verticalCenter
        text: Quickshell.env("USER") || "user"
        font.family: s.font; font.pixelSize: 13; font.weight: 800; color: s.fg
      }
      Row {
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        IconBtn { icon: "\u{F0128}"; onClicked: { s.host.dashboardOpen = false; Quickshell.execDetached(["omarchy-launch-or-focus-tui", "btop"]) } }
        IconBtn { icon: "\u{F0493}"; onClicked: { s.host.dashboardOpen = false; Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "kamradsmeshnyavy.customizer"]) } }
        IconBtn { icon: "\u{F019E}"; onClicked: { s.host.dashboardOpen = false; Quickshell.execDetached(["omarchy-capture-screenshot"]) } }
        IconBtn { icon: "\u{F0425}"; tint: s.red; fill: s.alpha(s.red, 0.15); onClicked: { s.host.dashboardOpen = false; s.host.powerOpen = true } }
      }
    }

    // плеер во всю ширину
    Card {
      id: media
      readonly property var p: s.host.player
      visible: !!p
      height: 96
      clip: true
      readonly property string art: p && p.trackArtUrl ? String(p.trackArtUrl) : ""
      Image { id: artBg; anchors.fill: parent; source: media.art; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(200, 200); visible: false }
      MultiEffect { anchors.fill: parent; source: artBg; visible: artBg.status === Image.Ready; blurEnabled: true; blur: 1; blurMax: 64; saturation: 0.35
        maskEnabled: true; maskSource: mediaMask; maskThresholdMin: 0.5 }
      Rectangle { id: mediaMask; anchors.fill: parent; radius: 10; visible: false; layer.enabled: true }
      Rectangle { anchors.fill: parent; radius: 10; color: s.alpha(s.dark ? "#000000" : "#ffffff", artBg.status === Image.Ready ? 0.5 : 0) }
      Rectangle {
        id: cover
        x: 12; anchors.verticalCenter: parent.verticalCenter
        width: 70; height: 70; radius: 6; color: s.item
        Image { id: coverImg; anchors.fill: parent; source: media.art; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(140, 140); visible: false; layer.enabled: true }
        Rectangle { id: coverMask; anchors.fill: parent; radius: 6; visible: false; layer.enabled: true }
        MultiEffect { anchors.fill: parent; source: coverImg; visible: coverImg.status === Image.Ready; maskEnabled: true; maskSource: coverMask; maskThresholdMin: 0.5 }
        Glyph { anchors.centerIn: parent; visible: coverImg.status !== Image.Ready; text: "\u{F075A}"; font.pixelSize: 26; color: s.text2 }
      }
      Column {
        anchors.left: cover.right; anchors.leftMargin: 12
        anchors.right: playBtn.left; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Text { width: parent.width; elide: Text.ElideRight; text: media.p ? media.p.trackTitle || "—" : ""; font.family: s.font; font.pixelSize: 13; font.weight: 700; color: s.fg }
        Text { width: parent.width; elide: Text.ElideRight; text: media.p ? media.p.trackArtist || "" : ""; font.family: s.font; font.pixelSize: 10; color: s.text2 }
        Text {
          function mmss(x) { x = Math.max(0, Math.floor(x || 0)); return Math.floor(x / 60) + ":" + ("0" + (x % 60)).slice(-2) }
          text: media.p ? mmss(media.p.position) + " / " + mmss(media.p.length) : ""
          font.family: s.font; font.pixelSize: 8; color: s.text2
        }
        Row {
          width: parent.width
          spacing: 6
          Glyph { text: "\u{F04AE}"; font.pixelSize: 10; color: s.text2; anchors.verticalCenter: parent.verticalCenter
            TapHandler { onTapped: if (media.p) media.p.previous() } HoverHandler { cursorShape: Qt.PointingHandCursor } }
          Item {
            id: wave
            width: parent.width - 40; height: 12
            anchors.verticalCenter: parent.verticalCenter
            readonly property real kk: media.p && media.p.length > 0 ? Math.max(0, Math.min(1, media.p.position / media.p.length)) : 0
            property real phase: 0
            NumberAnimation on phase { from: 0; to: Math.PI * 2; duration: 1400; loops: Animation.Infinite; running: !!media.p && media.p.isPlaying && s.live }
            Shape {
              anchors.fill: parent
              preferredRendererType: Shape.CurveRenderer
              ShapePath {
                strokeColor: s.fg; strokeWidth: 2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: 0; startY: 6
                PathPolyline { path: { var pts = [], n = 60, w = wave.width * wave.kk; for (var i = 0; i <= n; i++) { var x = w * i / n; pts.push(Qt.point(x, 6 + 2.6 * Math.sin(x / 4 - wave.phase))) } return pts } }
              }
              ShapePath {
                strokeColor: s.alpha(s.fg, 0.3); strokeWidth: 2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                startX: wave.width * wave.kk + 3; startY: 6
                PathLine { x: wave.width; y: 6 }
              }
            }
          }
          Glyph { text: "\u{F04AD}"; font.pixelSize: 10; color: s.text2; anchors.verticalCenter: parent.verticalCenter
            TapHandler { onTapped: if (media.p) media.p.next() } HoverHandler { cursorShape: Qt.PointingHandCursor } }
        }
      }
      Rectangle {
        id: playBtn
        anchors.right: parent.right; anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 34; height: 34; radius: 8
        color: pbh.hovered ? s.itemHover : s.alpha(s.fg, 0.12)
        Glyph { anchors.centerIn: parent; text: media.p && media.p.isPlaying ? "\u{F03E4}" : "\u{F040A}"; font.pixelSize: 15 }
        HoverHandler { id: pbh; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: if (media.p) media.p.togglePlaying() }
      }
    }

    // календарь | кнопки и ползунки
    Row {
      spacing: 10
      SurfCalendar {
        width: (s.width - 10) / 2; height: 214
        big: true
        host: s.host
        live: s.live
        card: s.card; fg: s.fg; text2: s.text2; acc: s.acc; onAcc: s.onAcc; font: s.font; icons: s.icons
      }
      Card {
        width: (s.width - 10) / 2; height: 214
        Row {
          anchors.centerIn: parent
          spacing: 18
          Column {
            spacing: 14
            VBtn { icon: st.wifi ? "\u{F05A9}" : "\u{F05AA}"; label: st.wifi ? (st.ssid || "Wi-Fi") : "Off"; on: st.wifi; onClicked: st.toggleWifi()
              onRightClicked: { s.host.dashboardOpen = false; Quickshell.execDetached(["omarchy-shell", "omarchy.network", "toggle"]) } }
            VBtn { icon: st.bt ? "\u{F00AF}" : "\u{F00B2}"; label: st.bt ? "On" : "Off"; on: st.bt; onClicked: st.toggleBt()
              onRightClicked: { s.host.dashboardOpen = false; Quickshell.execDetached(["omarchy-shell", "omarchy.bluetooth", "toggle"]) } }
            VBtn {
              icon: st.profile === "performance" ? "\u{F04C5}" : st.profile === "power-saver" ? "\u{F032A}" : "\u{F0EE1}"
              label: st.profile === "performance" ? "Max" : st.profile === "power-saver" ? "Save" : "Auto"
              on: st.profile === "performance"
              onClicked: st.cycleProfile()
            }
            VBtn { icon: st.dnd ? "\u{F009B}" : "\u{F009A}"; label: st.dnd ? "Silent" : "Notify"; on: !st.dnd; onClicked: st.toggleDnd() }
          }
          VSlider { height: 188; icon: "\u{F00DF}"; value: Math.max(0, st.bright); visible: st.bright >= 0; onMoved: function(v) { st.setBright(v) } }
          VSlider { height: 188; icon: st.muted ? "\u{F075F}" : "\u{F057E}"; value: st.vol; onMoved: function(v) { st.setVol(v) } }
        }
      }
    }

    // ближайшие напоминания
    Card {
      height: up.implicitHeight + 22
      Column {
        id: up
        x: 14; y: 11
        width: parent.width - 28
        spacing: 5
        Text { text: "Upcoming"; font.family: s.font; font.pixelSize: 11; font.weight: 800; color: s.fg }
        Repeater {
          model: st.reminders.slice(0, 2)
          Item {
            required property var modelData
            width: up.width; height: 16
            Row {
              spacing: 8
              Text { text: Qt.formatDate(new Date(modelData.at * 1000), "ddd"); font.family: s.font; font.pixelSize: 10; color: s.acc }
              Text { text: modelData.label || ""; font.family: s.font; font.pixelSize: 10; color: s.fg }
            }
            Text { anchors.right: parent.right; text: (modelData.atTime || "") + (modelData.remaining ? " · " + modelData.remaining : ""); font.family: s.font; font.pixelSize: 9; color: s.text2 }
          }
        }
        Text {
          visible: st.reminders.length === 0
          text: "Nothing planned · omarchy reminder"
          font.family: s.font; font.pixelSize: 10; color: s.text2
        }
      }
    }

    // уведомления
    Card {
      height: nc.implicitHeight + 20
      Column {
        id: nc
        x: 14; y: 10
        width: parent.width - 28
        spacing: 8
        Item {
          width: parent.width; height: 22
          Text { anchors.verticalCenter: parent.verticalCenter; text: "Notifications"; font.family: s.font; font.pixelSize: 11; font.weight: 800; color: s.fg }
          Row {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Rectangle {
              width: 20; height: 20; radius: 10; color: s.item
              Text { anchors.centerIn: parent; text: st.notes.length; font.family: s.font; font.pixelSize: 9; font.weight: 700; color: s.fg }
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
              TapHandler { onTapped: st.clearNotes() }
            }
          }
        }
        Repeater {
          model: s.notesOpen ? st.notes.slice(0, 4) : []
          Rectangle {
            required property var modelData
            width: nc.width; height: 40; radius: 8
            color: s.item
            Column {
              x: 12; anchors.verticalCenter: parent.verticalCenter
              width: parent.width - 24
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

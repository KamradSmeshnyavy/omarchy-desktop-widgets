import QtQuick
import Quickshell
import "glyph" as Glyph
import "dotmatrix" as DotMatrix

// Дашборд Glyph (свой, в духе glyph-rice и Nothing: чёрные карточки со скруглением 28, точечный Doto, Space Mono
// капителью, один красный акцент — GTheme). 720 × 420: слева огромное время точками и дата, мигающая красная точка
// секунд, uptime; справа три круговые шкалы из точек — CPU / MEM / DISK; ниже плеер с точечной обложкой (DotScreen),
// названием Doto и рядом точек прогресса; низ — круглые переключатели (wifi, bt, dnd, night, mic) и красная кнопка
// питания. С клавиатуры — KeyNav дашборда.
Item {
  id: g
  required property var host
  property real rise: 1
  readonly property bool live: rise > 0.01
  width: 720
  height: 420
  opacity: rise
  transform: Translate { y: (1 - g.rise) * -12 }

  readonly property var th: Glyph.GTheme
  readonly property string dot: Qt.fontFamilies().indexOf("Doto") !== -1 ? "Doto" : th.mono
  SurfState { id: st; live: g.live }
  SysStats { id: ss; live: g.live }
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: g.live; triggeredOnStart: true; onTriggered: g.now = new Date() }

  component Card: Rectangle { radius: 28; color: g.th.s1; border.width: 1; border.color: g.th.s2 }
  component Cap: Text { font.family: g.th.mono; font.pixelSize: 10; font.letterSpacing: 1.6; color: g.th.grey }
  component Circ: Rectangle {
    id: cb
    property string icon: ""
    property bool on: false
    property bool danger: false
    signal hit()
    width: 52; height: 52; radius: 26
    color: on ? g.th.fg : danger && h.hovered ? g.th.accent : h.hovered ? g.th.s3 : g.th.s2
    Text { anchors.centerIn: parent; text: cb.icon; color: cb.on ? g.th.bg : cb.danger ? (h.hovered ? g.th.bg : g.th.accent) : g.th.fg; font.pixelSize: 20 }
    HoverHandler { id: h; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: cb.hit() }
  }

  // время
  Card {
    width: 340; height: 210
    Row {
      x: 22; y: 18; spacing: 8
      Rectangle { width: 7; height: 7; radius: 3.5; color: g.th.accent; anchors.verticalCenter: parent.verticalCenter; opacity: g.now.getSeconds() % 2 ? 1 : 0.25 }
      Cap { text: "LOCAL TIME" }
    }
    Text { x: 18; y: 34; text: Qt.formatTime(g.now, "HH:mm"); color: g.th.fg; font.family: g.dot; font.pixelSize: 104; font.weight: 800 }
    Cap { x: 22; y: 150; text: Qt.formatDate(g.now, "dddd · d MMMM").toUpperCase(); color: g.th.fg }
    Cap { x: 22; y: 172; text: "UP " + String(st.uptime || "—").toUpperCase(); width: 300; elide: Text.ElideRight }
  }

  // шкалы
  Card {
    x: 352; width: 368; height: 210
    Cap { x: 22; y: 18; text: "SYSTEM" }
    Row {
      x: 18; y: 44; spacing: 14
      Repeater {
        model: [["CPU", ss.cpu], ["MEM", ss.mem], ["DISK", ss.disk]]
        Item {
          required property var modelData
          width: 100; height: 140
          Canvas {
            id: ring
            width: 100; height: 100
            property real v: modelData[1]
            onVChanged: requestPaint()
            onPaint: {
              var c = getContext("2d"); c.reset()
              var n = 36, lit = Math.round(v * n)
              for (var i = 0; i < n; i++) {
                var a = -Math.PI / 2 + i / n * Math.PI * 2
                c.fillStyle = i < lit ? (v > 0.85 ? g.th.accent : g.th.fg) : g.th.s3
                c.beginPath(); c.arc(50 + Math.cos(a) * 42, 50 + Math.sin(a) * 42, 3, 0, Math.PI * 2); c.fill()
              }
            }
            Text { anchors.centerIn: parent; text: Math.round(modelData[1] * 100); color: g.th.fg; font.family: g.dot; font.pixelSize: 30; font.weight: 800 }
          }
          Cap { anchors.horizontalCenter: parent.horizontalCenter; y: 112; text: modelData[0] }
        }
      }
    }
  }

  // плеер
  Card {
    id: pc
    y: 222; width: 720; height: 112
    readonly property var p: g.host.player
    DotMatrix.DotScreen { x: 14; y: 14; width: 84; height: 84; source: pc.p ? String(pc.p.trackArtUrl || "") : ""; pitch: 4; radius: 18 }
    Row {
      x: 114; y: 16; spacing: 6
      Rectangle { width: 6; height: 6; radius: 3; color: pc.p && pc.p.isPlaying ? g.th.accent : g.th.mute; anchors.verticalCenter: parent.verticalCenter }
      Cap { text: pc.p && pc.p.isPlaying ? "PLAYING" : "PAUSED" }
    }
    Text { x: 114; y: 32; width: 420; elide: Text.ElideRight; text: pc.p && pc.p.trackTitle ? pc.p.trackTitle : "Nothing playing"; color: g.th.fg; font.family: g.dot; font.pixelSize: 26; font.weight: 800 }
    Cap { x: 114; y: 66; width: 420; elide: Text.ElideRight; text: pc.p ? String(pc.p.trackArtist || "").toUpperCase() : "" }
    Row {
      x: 114; y: 88; spacing: 3
      Repeater { model: 70; Rectangle { required property int index; width: 4; height: 4; radius: 2; color: pc.p && pc.p.length > 0 && index / 70 <= pc.p.position / pc.p.length ? g.th.fg : g.th.s3 } }
    }
    Row {
      anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter; spacing: 10
      Circ { width: 44; height: 44; radius: 22; icon: "\u{F04AE}"; onHit: if (pc.p) pc.p.previous() }
      Circ { icon: pc.p && pc.p.isPlaying ? "\u{F03E4}" : "\u{F040A}"; on: !!pc.p && pc.p.isPlaying; onHit: if (pc.p) pc.p.togglePlaying() }
      Circ { width: 44; height: 44; radius: 22; icon: "\u{F04AD}"; onHit: if (pc.p) pc.p.next() }
    }
  }

  // переключатели и питание
  Card {
    y: 346; width: 720; height: 74
    Row {
      x: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 10
      Circ { icon: "\u{F05A9}"; on: st.wifi; onHit: st.toggleWifi() }
      Circ { icon: "\u{F00AF}"; on: st.bt; onHit: st.toggleBt() }
      Circ { icon: "\u{F009B}"; on: st.dnd; onHit: st.toggleDnd() }
      Circ { icon: "\u{F0594}"; on: st.night; onHit: st.toggleNight() }
      Circ { icon: "\u{F036C}"; on: !st.micMuted; onHit: st.toggleMic() }
    }
    Row {
      anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 10
      Circ { icon: "\u{F033E}"; onHit: { g.host.dashboardOpen = false; Quickshell.execDetached(["omarchy-system-lock"]) } }
      Circ { icon: "\u{F0425}"; danger: true; onHit: { g.host.dashboardOpen = false; g.host.powerOpen = true } }
    }
  }
}

import QtQuick
import QtQuick.Effects

// Карточка плеера Vitreus (mediaStyle "vitreus"; по облику из его поста в r/unixporn — github.com/natepayn3/Vitreus, MIT;
// код свой). 288 × 148: обложка 92 px со скруглением, справа название и исполнитель, под ними полосы визуализатора
// (cava; без звука — точки), под обложкой кнопки назад / круглая пауза / вперёд, внизу время, шкала с бегунком и длина.
// Открепленная (плавает на столе) — ручка по центру сверху и булавка справа: вернуть карточку на место.
// Стекло под ней рисует WidgetCard (материал стиля), здесь только содержимое.
Item {
  id: vc

  required property var host
  property bool floating: false
  signal pinned()

  readonly property var player: host.player
  readonly property color ink: host.foreground
  readonly property color mint: host.accent
  function a(c, k) { return Qt.rgba(c.r, c.g, c.b, k) }
  readonly property string font: Qt.fontFamilies().indexOf("Space Grotesk") !== -1 ? "Space Grotesk" : host.fontFamily
  readonly property real progress: player && player.lengthSupported && player.length > 0
    ? Math.max(0, Math.min(1, player.position / player.length)) : 0
  function clock(s) {
    s = Math.max(0, Math.floor(s || 0))
    var m = Math.floor(s / 60), r = s % 60
    return m + ":" + (r < 10 ? "0" : "") + r
  }

  width: 288; height: 148

  // ручка (плавает) — за неё и за любое место карточки её носят
  Rectangle {
    visible: vc.floating
    anchors.horizontalCenter: parent.horizontalCenter
    y: 3
    width: 34; height: 3; radius: 1.5
    color: vc.ink
    opacity: grab.hovered ? 0.55 : 0.2
  }
  HoverHandler { id: grab }
  // булавка — вернуть на место
  Item {
    visible: vc.floating
    x: parent.width - 30; y: 6
    width: 20; height: 20
    Rectangle { anchors.fill: parent; radius: 10; color: vc.ink; opacity: pinHover.hovered ? 0.22 : 0.08 }
    Rectangle { x: 7.4; y: 4.4; width: 5.2; height: 5.2; radius: 2.6; color: "transparent"; border.width: 1.2; border.color: vc.a(vc.ink, pinHover.hovered ? 1 : 0.7) }
    Rectangle { x: 9.4; y: 9.6; width: 1.2; height: 4.6; color: vc.a(vc.ink, pinHover.hovered ? 1 : 0.7) }
    HoverHandler { id: pinHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: vc.pinned() }
  }

  // обложка
  Item {
    id: cover
    x: 14; y: 14
    width: 92; height: 92
    Rectangle {
      anchors.fill: parent; radius: 12
      color: vc.a(vc.mint, 0.18)
      Text { anchors.centerIn: parent; visible: art.status !== Image.Ready; text: "󰎆"; font.family: vc.host.iconFamily; font.pixelSize: 36; color: vc.mint }
    }
    Image {
      id: art
      anchors.fill: parent
      source: vc.player ? String(vc.player.trackArtUrl || "") : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      sourceSize: Qt.size(184, 184)
      visible: false
    }
    Rectangle { id: artMask; anchors.fill: parent; radius: 12; visible: false; layer.enabled: true }
    MultiEffect { anchors.fill: parent; source: art; maskEnabled: true; maskSource: artMask; visible: art.status === Image.Ready }
  }

  // название, исполнитель
  Text {
    x: 118; y: 15; width: parent.width - 118 - (vc.floating ? 36 : 14)
    elide: Text.ElideRight
    text: vc.player && vc.player.trackTitle ? vc.player.trackTitle : vc.host.tr("Nothing playing", "Ничего не играет")
    color: vc.ink
    font { family: vc.font; pixelSize: 13; weight: Font.Bold }
  }
  Text {
    x: 118; y: 34; width: parent.width - 132
    elide: Text.ElideRight
    text: vc.player ? String(vc.player.trackArtist || vc.player.identity || "") : ""
    color: vc.a(vc.ink, 0.6)
    font { family: vc.font; pixelSize: 11 }
  }

  // полосы визуализатора: от нижней линии, без звука — точки
  Row {
    id: bars
    x: 118; y: 58
    height: 40
    spacing: 2.2
    readonly property int n: 26
    readonly property var lv: vc.host.levels || []
    Repeater {
      model: bars.n
      Rectangle {
        required property int index
        readonly property real l: {
          var v = bars.lv
          if (!v.length || !vc.host.playing) return 0
          var i = Math.floor(index / bars.n * v.length)
          return Math.max(0, Math.min(1, Number(v[i]) || 0))
        }
        width: 3.6
        height: Math.max(3.6, bars.height * l)
        radius: 1.8
        y: bars.height - height
        color: vc.ink
        opacity: 0.85
      }
    }
  }

  // кнопки под обложкой
  Row {
    x: 14; y: 108
    width: 92; height: 22
    spacing: 4
    Repeater {
      model: [
        { glyph: "󰒮", act: "previous" },
        { glyph: vc.host.playing ? "󰏤" : "󰐊", act: "toggle" },
        { glyph: "󰒭", act: "next" }
      ]
      delegate: Item {
        required property var modelData
        width: modelData.act === "toggle" ? 24 : 30; height: 22
        Rectangle {
          visible: modelData.act === "toggle"
          anchors.centerIn: parent
          width: 22; height: 22; radius: 11
          color: vc.ink
          opacity: btnHover.hovered ? 1 : 0.9
        }
        Text {
          anchors.centerIn: parent
          text: modelData.glyph
          font.family: vc.host.iconFamily
          font.pixelSize: modelData.act === "toggle" ? 15 : 15
          color: modelData.act === "toggle" ? vc.host.background : vc.a(vc.ink, btnHover.hovered ? 1 : 0.75)
        }
        HoverHandler { id: btnHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
          onTapped: {
            if (!vc.player) return
            if (modelData.act === "previous") vc.player.previous()
            else if (modelData.act === "next") vc.player.next()
            else vc.player.togglePlaying()
          }
        }
      }
    }
  }

  // время, шкала, длина
  Text {
    x: 14; y: 131
    text: vc.clock(vc.player ? vc.player.position : 0)
    color: vc.a(vc.ink, 0.7)
    font { family: vc.font; pixelSize: 9 }
  }
  Text {
    anchors.right: parent.right; anchors.rightMargin: 14; y: 131
    text: vc.clock(vc.player ? vc.player.length : 0)
    color: vc.a(vc.ink, 0.7)
    font { family: vc.font; pixelSize: 9 }
  }
  Item {
    id: seek
    x: 46; y: 129
    width: parent.width - 46 - 46; height: 14
    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 2.4; radius: 1.2; color: vc.a(vc.ink, 0.22) }
    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * vc.progress; height: 2.4; radius: 1.2; color: vc.ink }
    Rectangle {
      x: parent.width * vc.progress - width / 2; anchors.verticalCenter: parent.verticalCenter
      width: 9; height: 9; radius: 4.5
      color: vc.ink
    }
    TapHandler {
      onTapped: function(ev) {
        var p = vc.player
        if (p && p.canSeek && p.lengthSupported && p.length > 0) p.position = Math.max(0, Math.min(1, ev.position.x / seek.width)) * p.length
      }
    }
  }
}

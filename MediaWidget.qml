import QtQuick
import QtQuick.Effects
import "dotmatrix" as DotMatrix

// Карточка «сейчас играет» (MPRIS): обложка, название, исполнитель, прогресс, кнопки.
Rectangle {
  id: card

  required property var host
  readonly property var player: host.player
  readonly property bool dotmatrix: host.dotmatrixWidgets
  // mediaStyle "yami": широкая карточка «♫ silence — nothing playing» / «♫ трек — исполнитель», полосы визуализатора
  // и линия прогресса акцентом (по мотивам yami, MIT; код свой); видна и без плеера
  readonly property bool yami: !dotmatrix && String(host.value("mediaStyle")) === "yami"
  // mediaStyle "bruteon": обложка в плитке с контуром и тенью, название, исполнитель, волна точек визуализатора, время
  // и плитки назад / пауза (лососевая) / вперёд (по мотивам Bruteon, Darkkal44 — облик со скриншота, код свой)
  readonly property bool brute: !dotmatrix && String(host.value("mediaStyle")) === "bruteon"

  width: yami ? 500 : brute ? 380 : dotmatrix ? 320 : 400   // DOT-MATRIX — ширина колонки карточек
  height: yami ? 150 : brute ? 140 : 120
  radius: 18
  // На подложке стиля (WidgetCard) своя заливка и рамка не нужны.
  color: host.styledWidgets ? "transparent" : (dotmatrix ? DotMatrix.Palette.bg : Qt.rgba(host.background.r, host.background.g, host.background.b, 0.62))
  border.width: host.styledWidgets ? 0 : 1
  border.color: dotmatrix ? DotMatrix.Palette.line : Qt.rgba(host.accent.r, host.accent.g, host.accent.b, 0.35)

  readonly property real progress: player && player.lengthSupported && player.length > 0
    ? Math.max(0, Math.min(1, player.position / player.length)) : 0

  Item {
    visible: !card.brute
    id: cover
    x: 12
    y: 12
    width: card.height - 24
    height: width

    DotMatrix.DotScreen {
      visible: card.dotmatrix
      anchors.fill: parent
      source: card.player ? String(card.player.trackArtUrl || "") : ""
      pitch: 4
      radius: 12
    }

    Rectangle {
      visible: !card.dotmatrix
      anchors.fill: parent
      radius: 12
      color: Qt.rgba(card.host.accent.r, card.host.accent.g, card.host.accent.b, 0.18)
      Text {
        anchors.centerIn: parent
        text: "󰎆"
        font.family: card.host.iconFamily
        font.pixelSize: 40
        color: card.host.accent
        visible: art.status !== Image.Ready
      }
    }
    Image {
      id: art
      anchors.fill: parent
      source: !card.dotmatrix && card.player ? card.player.trackArtUrl : ""
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      sourceSize.width: 192
      sourceSize.height: 192
      visible: false
    }
    Rectangle {
      id: artMask
      anchors.fill: parent
      radius: 12
      visible: false
      layer.enabled: true
    }
    MultiEffect {
      anchors.fill: parent
      source: art
      maskEnabled: true
      maskSource: artMask
      visible: !card.dotmatrix && art.status === Image.Ready
    }
  }

  Column {
    visible: !card.brute
    anchors { left: cover.right; leftMargin: 14; right: parent.right; rightMargin: 16; top: parent.top; topMargin: 14 }
    spacing: 2

    Text {
      width: parent.width
      text: card.player && card.player.trackTitle ? card.player.trackTitle : card.host.tr("Nothing playing", "Ничего не играет")
      elide: Text.ElideRight
      font.family: card.dotmatrix ? DotMatrix.Palette.fontTitle : card.host.fontFamily
      font.pixelSize: 17
      font.weight: card.dotmatrix ? DotMatrix.Palette.titleWeight(Font.Medium) : Font.Bold
      color: card.dotmatrix ? DotMatrix.Palette.fg : card.host.foreground
    }
    Text {
      width: parent.width
      text: card.player ? (card.player.trackArtist || card.player.identity) : "MEDIA"
      elide: Text.ElideRight
      font.family: card.dotmatrix ? DotMatrix.Palette.fontMono : card.host.fontFamily
      font.pixelSize: card.dotmatrix ? 11 : 13
      font.letterSpacing: card.dotmatrix ? 1.4 : 0
      font.capitalization: card.dotmatrix ? Font.AllUppercase : Font.MixedCase
      color: card.dotmatrix ? DotMatrix.Palette.dim : card.host.foreground
      opacity: card.dotmatrix ? 1 : 0.7
    }
  }

  DotMatrix.DotMeter {
    visible: card.dotmatrix
    anchors { left: cover.right; leftMargin: 14; right: parent.right; rightMargin: 16; bottom: buttons.top; bottomMargin: 8 }
    count: Math.max(10, Math.floor((width + 3) / 7))
    dot: 4
    gap: 3
    value: card.progress
  }

  // Прогресс
  Rectangle {
    id: track
    visible: !card.dotmatrix && !card.brute
    anchors { left: cover.right; leftMargin: 14; right: parent.right; rightMargin: 16; bottom: buttons.top; bottomMargin: 8 }
    height: 4
    radius: 2
    color: Qt.rgba(card.host.foreground.r, card.host.foreground.g, card.host.foreground.b, 0.15)
    Rectangle {
      width: parent.width * card.progress
      height: parent.height
      radius: 2
      color: card.host.accent
      // без Behavior: позиция приходит раз в секунду, и плавный доезд 900 мс держал слой виджетов (полноэкранный, с
      // размытием) в непрерывной перерисовке всё время, пока играет музыка — Hyprland ~40 % видеокарты. Шаг раз в
      // секунду на 4-пиксельной полоске не виден.
    }
  }

  Row {
    visible: !card.brute
    id: buttons
    anchors { left: cover.right; leftMargin: 8; bottom: parent.bottom; bottomMargin: 8 }
    spacing: 4

    Repeater {
      model: [
        { glyph: "󰒮", act: "previous", enabled: card.player && card.player.canGoPrevious },
        { glyph: card.host.playing ? "󰏤" : "󰐊", act: "toggle", enabled: card.player && card.player.canTogglePlaying },
        { glyph: "󰒭", act: "next", enabled: card.player && card.player.canGoNext }
      ]
      delegate: Rectangle {
        required property var modelData
        width: 34
        height: 30
        radius: 8
        color: hover.hovered ? Qt.rgba(card.host.accent.r, card.host.accent.g, card.host.accent.b, 0.2) : "transparent"
        opacity: modelData.enabled ? 1 : 0.35
        Text {
          anchors.centerIn: parent
          text: modelData.glyph
          font.family: card.host.iconFamily
          font.pixelSize: 20
          color: modelData.act === "toggle" ? card.host.accent : card.host.foreground
        }
        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
          enabled: modelData.enabled
          onTapped: {
            if (!card.player) return
            if (modelData.act === "previous") card.player.previous()
            else if (modelData.act === "next") card.player.next()
            else card.player.togglePlaying()
          }
        }
      }
    }
  }

  // ── bruteon ─────────────────────────────────────────────────────────
  Item {
    id: bru
    visible: card.brute
    anchors.fill: parent
    z: 50
    readonly property color ink: card.host.foreground
    readonly property string mono: Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : card.host.fontFamily
    function mmss(x) { x = Math.max(0, Math.floor(x || 0)); return Math.floor(x / 60) + ":" + ("0" + (x % 60)).slice(-2) }
    // фон под обложкой и текстом — цвет карточки (перекрывает обычный вид)
    Rectangle { anchors.fill: parent; radius: 12; color: card.host.styledWidgets ? "transparent" : card.host.background }
    Item {
      x: 14; y: 14; width: 108; height: 108
      Rectangle { x: 3; y: 3; width: 108; height: 108; radius: 12; color: bru.ink }
      Rectangle {
        id: bruCover
        width: 108; height: 108; radius: 12
        color: Qt.tint(card.host.background, Qt.rgba(bru.ink.r, bru.ink.g, bru.ink.b, 0.12)); border.width: 2.5; border.color: bru.ink
        Image { id: bruArt; anchors.fill: parent; anchors.margins: 3; source: card.player ? String(card.player.trackArtUrl || "") : ""; fillMode: Image.PreserveAspectCrop; visible: false; layer.enabled: true }
        Rectangle { id: bruMask; anchors.fill: bruArt; radius: 9; visible: false; layer.enabled: true }
        MultiEffect { anchors.fill: bruArt; source: bruArt; visible: bruArt.status === Image.Ready; maskEnabled: true; maskSource: bruMask; maskThresholdMin: 0.5 }
        Text { anchors.centerIn: parent; visible: bruArt.status !== Image.Ready; text: "\u{F075A}"; color: bru.ink; opacity: 0.5; font.family: card.host.iconFamily; font.pixelSize: 34 }
      }
    }
    Column {
      x: 138; y: 16
      width: parent.width - 152
      spacing: 3
      Text { width: parent.width; elide: Text.ElideRight; text: card.player && card.player.trackTitle ? card.player.trackTitle : card.host.tr("Nothing playing", "Ничего не играет"); color: bru.ink; font.family: bru.mono; font.pixelSize: 13 }
      Text { width: parent.width; elide: Text.ElideRight; text: card.player ? (card.player.trackArtist || "") : ""; color: Qt.rgba(bru.ink.r, bru.ink.g, bru.ink.b, 0.6); font.family: bru.mono; font.pixelSize: 10 }
    }
    // волна точек: высота — уровень визуализатора, сыгранная часть — чернилами, остальное — бледнее
    Row {
      x: 138; y: 62
      spacing: 3
      Repeater {
        model: 24
        Rectangle {
          required property int index
          readonly property var lv: card.host.levels || []
          readonly property real v: lv.length ? Number(lv[Math.floor(index * lv.length / 24)] || 0) : 0
          width: 6; height: 5 + 10 * Math.min(1, v); radius: 3
          anchors.verticalCenter: parent ? parent.verticalCenter : undefined
          color: bru.ink
          opacity: index / 24 <= card.progress ? 1 : 0.3
        }
      }
    }
    Text { x: 138; y: 100; text: card.player ? bru.mmss(card.player.position) : "0:00"; color: bru.ink; font.family: bru.mono; font.pixelSize: 10; font.bold: true }
    Text { anchors.right: parent.right; anchors.rightMargin: 16; y: 100; text: card.player ? bru.mmss(card.player.length) : "0:00"; color: bru.ink; font.family: bru.mono; font.pixelSize: 10; font.bold: true }
    Row {
      x: 138 + (parent.width - 152) / 2 - width / 2; y: 92
      spacing: 10
      Repeater {
        model: [["", "previous", "#fbf3ee", 26], [card.player && card.player.isPlaying ? "" : "", "togglePlaying", "#ffb3a1", 32], ["", "next", "#fbf3ee", 26]]
        Item {
          id: bb
          required property var modelData
          width: modelData[3]; height: modelData[3]
          anchors.verticalCenter: parent ? parent.verticalCenter : undefined
          readonly property real lift: bbTap.pressed ? 0 : bbHov.hovered ? 3 : 2
          Rectangle { x: 2; y: 2; width: bb.width; height: bb.height; radius: 8; color: bru.ink }
          Rectangle {
            x: 2 - bb.lift; y: 2 - bb.lift; width: bb.width; height: bb.height; radius: 8
            color: bb.modelData[2]; border.width: 2; border.color: bru.ink
            Text { anchors.centerIn: parent; text: bb.modelData[0]; color: "#161110"; font.family: bru.mono; font.pixelSize: 10 }
          }
          HoverHandler { id: bbHov; cursorShape: Qt.PointingHandCursor }
          TapHandler { id: bbTap; onTapped: if (card.player) card.player[bb.modelData[1]]() }
        }
      }
    }
  }

  // ── yami ────────────────────────────────────────────────────────────
  Rectangle {
    visible: card.yami
    anchors.fill: parent
    z: 50
    color: Qt.rgba(card.host.background.r * 0.85, card.host.background.g * 0.85, card.host.background.b * 0.85, 1)
    border.width: 1
    border.color: Qt.rgba(card.host.foreground.r, card.host.foreground.g, card.host.foreground.b, 0.16)
    readonly property string px: Qt.fontFamilies().indexOf("Tiny5") !== -1 ? "Tiny5" : card.host.fontFamily
    readonly property bool has: !!card.player && String(card.player.trackTitle || "") !== ""
    Text { x: 12; y: 10; text: "󰎈"; color: card.host.accent; font.family: card.host.iconFamily; font.pixelSize: 14 }
    Text {
      x: 32; y: 10; width: parent.width - 44
      elide: Text.ElideRight
      text: parent.has ? card.player.trackTitle + (card.player.trackArtist ? " — " + card.player.trackArtist : "") : "silence — nothing playing"
      color: card.host.foreground; opacity: parent.has ? 0.8 : 0.45
      font.family: parent.px; font.pixelSize: 14
    }
    // визуализатор: столбики акцентом над линией прогресса
    Row {
      x: 12; y: parent.height - 18 - 70
      height: 70
      spacing: 2
      readonly property var lv: card.host.levels || []
      Repeater {
        model: 60
        Rectangle {
          required property int index
          readonly property var lv: parent.lv
          readonly property real v: lv.length ? (lv[Math.floor(index / 60 * lv.length)] || 0) : 0
          anchors.bottom: parent.bottom
          width: (500 - 24 - 59 * 2) / 60
          height: Math.max(1, 70 * Math.min(1, v))
          color: card.host.accent
          opacity: 0.8
        }
      }
    }
    Rectangle {
      x: 12; y: parent.height - 12; width: parent.width - 24; height: 2
      color: Qt.rgba(card.host.accent.r, card.host.accent.g, card.host.accent.b, 0.25)
      Rectangle { width: parent.width * card.progress; height: parent.height; color: card.host.accent }
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: parent.has ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: if (card.player) card.player.togglePlaying()
    }
  }
}

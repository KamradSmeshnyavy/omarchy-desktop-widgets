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

  width: yami ? 500 : dotmatrix ? 320 : 400   // DOT-MATRIX — ширина колонки карточек
  height: yami ? 150 : 120
  radius: 18
  // На подложке стиля (WidgetCard) своя заливка и рамка не нужны.
  color: host.styledWidgets ? "transparent" : (dotmatrix ? DotMatrix.Palette.bg : Qt.rgba(host.background.r, host.background.g, host.background.b, 0.62))
  border.width: host.styledWidgets ? 0 : 1
  border.color: dotmatrix ? DotMatrix.Palette.line : Qt.rgba(host.accent.r, host.accent.g, host.accent.b, 0.35)

  readonly property real progress: player && player.lengthSupported && player.length > 0
    ? Math.max(0, Math.min(1, player.position / player.length)) : 0

  Item {
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
    visible: !card.dotmatrix
    anchors { left: cover.right; leftMargin: 14; right: parent.right; rightMargin: 16; bottom: buttons.top; bottomMargin: 8 }
    height: 4
    radius: 2
    color: Qt.rgba(card.host.foreground.r, card.host.foreground.g, card.host.foreground.b, 0.15)
    Rectangle {
      width: parent.width * card.progress
      height: parent.height
      radius: 2
      color: card.host.accent
      Behavior on width { NumberAnimation { duration: 900 } }
    }
  }

  Row {
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

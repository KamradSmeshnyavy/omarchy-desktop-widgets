import QtQuick
import "dotmatrix" as DotMatrix

// Часы. Стили (clockStyle): big — крупное время и дата под ним; stacked — часы над
// минутами; terminal — «вывод команды date» с мигающим курсором; minimal — одна строка; vitreus — стеклянные цифры;
// yami — крупное пиксельное время (Tiny5) с жёсткой тенью.
Item {
  id: clock

  required property var host

  readonly property string style: String(host.value("clockStyle"))
  readonly property bool h24: host.value("clock24") !== false
  readonly property bool seconds: host.flag("clockSeconds")

  property date now: new Date()
  Timer {
    interval: 1000
    repeat: true
    running: clock.visible
    triggeredOnStart: true
    onTriggered: clock.now = new Date()
  }

  readonly property string hours: Qt.formatTime(now, h24 ? "HH" : "hh")
  readonly property string minutes: Qt.formatTime(now, "mm")
  readonly property string time: Qt.formatTime(now, (h24 ? "HH:mm" : "h:mm") + (seconds ? ":ss" : "") + (h24 ? "" : " AP"))
  readonly property string dateText: now.toLocaleDateString(host.locale, "dddd, d MMMM")

  implicitWidth: content.item ? content.item.implicitWidth : 0
  implicitHeight: content.item ? content.item.implicitHeight : 0
  width: implicitWidth
  height: implicitHeight

  Loader {
    id: content
    sourceComponent: clock.host.dotmatrixWidgets ? dotmatrixClock
      : clock.style === "stacked" ? stacked
      : clock.style === "terminal" ? terminal
      : clock.style === "minimal" ? minimal
      : clock.style === "vitreus" ? vitreusClock
      : clock.style === "yami" ? yamiClock : big
  }

  // yami: крупное время пиксельным Tiny5 с жёсткой тенью, под ним дата мелко и тускло
  Component {
    id: yamiClock
    Column {
      readonly property string px: Qt.fontFamilies().indexOf("Tiny5") !== -1 ? "Tiny5" : clock.host.fontFamily
      spacing: 6
      Item {
        width: t.implicitWidth + 4; height: t.implicitHeight + 4
        Text { x: 4; y: 4; text: t.text; font: t.font; color: Qt.rgba(0, 0, 0, 0.6) }
        Text { id: t; text: clock.time; color: Qt.rgba(clock.host.foreground.r, clock.host.foreground.g, clock.host.foreground.b, 0.62)
          font.family: parent.parent.px; font.pixelSize: 88 }
      }
      Text { x: 2; text: clock.dateText; color: clock.host.foreground; opacity: 0.4; font.family: parent.px; font.pixelSize: 15 }
    }
  }
  // vitreus: стеклянные цифры-трубки (VitClock), раскладка clockVitreusLayout: rule | pipe | digital
  Component {
    id: vitreusClock
    VitClock {
      hours: clock.hours
      minutes: clock.minutes
      layout: String(clock.host.value("clockVitreusLayout") || "rule")
      k: Math.max(0.6, Number(clock.host.value("clockVitreusSize")) || 1.4)
      tint: clock.host.background
    }
  }

  Component {
    id: dotmatrixClock
    Column {
      spacing: 2
      Text {
        text: "EX NIHILO"
        font.family: DotMatrix.Palette.fontMono
        font.pixelSize: 11
        font.letterSpacing: 2.2
        color: DotMatrix.Palette.muted
      }
      Text {
        text: clock.time
        font.family: DotMatrix.Palette.fontDot
        font.weight: Font.Bold
        font.pixelSize: 102
        color: DotMatrix.Palette.fg
      }
      Text {
        text: clock.dateText.toUpperCase()
        font.family: DotMatrix.Palette.fontMono
        font.pixelSize: 12
        font.letterSpacing: 1.8
        color: DotMatrix.Palette.dim
      }
    }
  }

  // Inline-компонент не видит id снаружи — шрифт и цвет задаются на месте.
  component Label: Text {
    renderType: Text.NativeRendering
    style: Text.Raised
    styleColor: Qt.rgba(0, 0, 0, 0.25)
  }

  Component {
    id: big
    Column {
      spacing: -6
      Label {
        font.family: clock.host.fontFamily
        text: clock.time
        font.pixelSize: 104
        font.weight: Font.Light
        color: clock.host.accent
      }
      Label {
        font.family: clock.host.fontFamily
        leftPadding: 6
        text: clock.dateText
        font.pixelSize: 22
        color: clock.host.foreground
        opacity: 0.85
      }
    }
  }

  Component {
    id: stacked
    Column {
      spacing: -38
      Label {
        font.family: clock.host.fontFamily
        text: clock.hours
        font.pixelSize: 132
        font.weight: Font.Black
        color: clock.host.accent
      }
      Label {
        font.family: clock.host.fontFamily
        text: clock.minutes
        font.pixelSize: 132
        font.weight: Font.Black
        color: clock.host.foreground
      }
      Label {
        font.family: clock.host.fontFamily
        topPadding: 30
        leftPadding: 6
        text: clock.dateText
        font.pixelSize: 18
        color: clock.host.foreground
        opacity: 0.8
      }
    }
  }

  Component {
    id: terminal
    Column {
      spacing: 4
      Label {
        font.family: clock.host.fontFamily
        text: "<font color='" + clock.host.accent + "'>❯</font> date +'%H:%M  %A %d %B'"
        textFormat: Text.StyledText
        font.pixelSize: 18
        color: clock.host.foreground
        opacity: 0.6
      }
      Row {
        spacing: 0
        Label {
          font.family: clock.host.fontFamily
          text: clock.time + "  " + clock.dateText
          font.pixelSize: 30
          font.weight: Font.Bold
          color: clock.host.foreground
        }
        Rectangle {
          width: 14
          height: 32
          anchors.verticalCenter: parent.verticalCenter
          color: clock.host.accent
          opacity: clock.now.getSeconds() % 2 === 0 ? 1 : 0
        }
      }
    }
  }

  Component {
    id: minimal
    Label {
      font.family: clock.host.fontFamily
      color: clock.host.foreground
      text: "<font color='" + clock.host.accent + "'>" + clock.time + "</font>  ·  " + clock.dateText
      textFormat: Text.StyledText
      font.pixelSize: 28
    }
  }
}

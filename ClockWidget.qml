import QtQuick
import Quickshell
import "dotmatrix" as DotMatrix

// Часы. Стили (clockStyle): big — крупное время и дата под ним; stacked — часы над
// минутами; terminal — «вывод команды date» с мигающим курсором; minimal — одна строка; vitreus — стеклянные цифры;
// yami — крупное пиксельное время (Tiny5) с жёсткой тенью; bruteon — карточка Bruteon: аналоговый циферблат и приветствие.
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
      : clock.style === "yami" ? yamiClock
      : clock.style === "bruteon" ? bruteClock : big
  }

  // bruteon (по мотивам карточки часов Bruteon, Darkkal44 — облик со скриншота, код свой): слева аналоговый циферблат с
  // контуром, метками часов и стрелками (секундная — красная), черта; справа «☾ Good evening, имя», крупное время с
  // лавандовой плашкой AM / PM и дата
  Component {
    id: bruteClock
    Row {
      id: bc
      readonly property color ink: clock.host.foreground
      readonly property string mono: Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : clock.host.fontFamily
      readonly property int h: clock.now.getHours()
      spacing: 22
      Item {
        width: 96; height: 96
        anchors.verticalCenter: parent.verticalCenter
        Rectangle { x: 3; y: 3; width: 96; height: 96; radius: 48; color: bc.ink }
        Rectangle {
          id: face
          width: 96; height: 96; radius: 48
          color: Qt.rgba(1, 1, 1, 0.94); border.width: 2.5; border.color: bc.ink
          Repeater {
            model: 12
            Rectangle {
              required property int index
              readonly property bool major: index % 3 === 0
              width: major ? 3 : 2; height: major ? 10 : 6; radius: 1
              color: "#161110"
              x: face.width / 2 - width / 2 + Math.sin(index * Math.PI / 6) * (face.width / 2 - 10 - height / 2)
              y: face.height / 2 - height / 2 - Math.cos(index * Math.PI / 6) * (face.height / 2 - 10 - height / 2)
              rotation: index * 30
            }
          }
          Repeater {
            model: [[(clock.now.getHours() % 12 + clock.now.getMinutes() / 60) * 30, 24, 3.5, "#161110"],
                    [(clock.now.getMinutes() + clock.now.getSeconds() / 60) * 6, 34, 2.5, "#161110"],
                    [clock.now.getSeconds() * 6, 36, 1.2, "#c0473b"]]
            Rectangle {
              required property var modelData
              width: modelData[2]; height: modelData[1]; radius: width / 2
              color: modelData[3]
              x: face.width / 2 - width / 2; y: face.height / 2 - height
              transformOrigin: Item.Bottom
              rotation: modelData[0]
            }
          }
          Rectangle { anchors.centerIn: parent; width: 7; height: 7; radius: 3.5; color: "#161110" }
        }
      }
      Rectangle { width: 1.5; height: 84; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(bc.ink.r, bc.ink.g, bc.ink.b, 0.25) }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        Row {
          spacing: 6
          Text { anchors.verticalCenter: parent.verticalCenter; text: bc.h < 6 || bc.h >= 19 ? "\u{F0594}" : bc.h < 12 ? "\u{F059C}" : "\u{F0599}"; color: "#e07a5f"; font.family: clock.host.iconFamily; font.pixelSize: 13 }
          Text {
            text: (bc.h < 5 ? "Good night" : bc.h < 12 ? "Good morning" : bc.h < 18 ? "Good afternoon" : "Good evening") + ", " + (Quickshell.env("USER") || "")
            color: bc.ink; font.family: bc.mono; font.pixelSize: 12; font.bold: true
          }
        }
        Row {
          spacing: 10
          Text { text: Qt.formatTime(clock.now, clock.h24 ? "HH:mm" : "h:mm AP").split(" ")[0]; color: bc.ink; font.family: bc.mono; font.pixelSize: 40; font.bold: true }
          Rectangle {
            visible: !clock.h24
            anchors.verticalCenter: parent.verticalCenter
            width: ap.implicitWidth + 10; height: 20; radius: 5
            color: "#dcc4ec"; border.width: 2; border.color: bc.ink
            Text { id: ap; anchors.centerIn: parent; text: Qt.formatTime(clock.now, "AP"); color: "#161110"; font.family: bc.mono; font.pixelSize: 10; font.bold: true }
          }
        }
        Text { text: Qt.formatDate(clock.now, "dddd, MMMM d"); color: bc.ink; font.family: bc.mono; font.pixelSize: 11; font.bold: true }
      }
    }
  }

  // yami: крупное время пиксельным Tiny5 с жёсткой тенью — цифры светлые, двоеточие акцентом; под ним дата и шкала
  // дня из 16 штрихов (пройденная часть — акцентом)
  Component {
    id: yamiClock
    Column {
      id: yc
      readonly property string px: Qt.fontFamilies().indexOf("Tiny5") !== -1 ? "Tiny5" : clock.host.fontFamily
      readonly property real day: (clock.now.getHours() * 60 + clock.now.getMinutes()) / 1440
      spacing: 6
      Item {
        width: digits.implicitWidth + 4; height: digits.implicitHeight + 4
        Row {
          x: 4; y: 4
          Repeater {
            model: [clock.hours, ":", clock.minutes]
            Text { required property var modelData; text: modelData; color: Qt.rgba(0, 0, 0, 0.65); font.family: yc.px; font.pixelSize: 88 }
          }
        }
        Row {
          id: digits
          Text { text: clock.hours; color: clock.host.foreground; font.family: yc.px; font.pixelSize: 88 }
          Text { text: ":"; color: clock.host.accent; font.family: yc.px; font.pixelSize: 88 }
          Text { text: clock.minutes; color: clock.host.foreground; font.family: yc.px; font.pixelSize: 88 }
        }
      }
      Text { x: 2; text: clock.dateText; color: clock.host.foreground; opacity: 0.55; font.family: yc.px; font.pixelSize: 15 }
      Row {
        x: 2
        spacing: 4
        Repeater {
          model: 16
          Rectangle {
            required property int index
            width: 20; height: 3
            color: index < Math.round(yc.day * 16) ? clock.host.accent : Qt.rgba(clock.host.accent.r, clock.host.accent.g, clock.host.accent.b, 0.22)
          }
        }
      }
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

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io

// Дашборд Rumda (dashStyle "rumda", по мотивам hexonide/rumda — только облик, код свой): плотная карточка из блоков
// цвета «модуля». Слева — аватар в двойном круге и столбик кнопок питания (выключение, выход, перезагрузка, блокировка,
// заметки); справа — «Hello..» и имя, ряд кнопок (файлы, поиск, снимок, терминал, Bluetooth) и плеер (назад,
// пауза, вперёд); узкая колонка — яркость (стрелки и полоса); снизу — график вкладов GitHub (ContribWidget).
Item {
  id: r

  required property var host
  property real rise: 1
  readonly property color fg: host.foreground
  readonly property color bg: host.background
  readonly property color acc: host.accent
  readonly property string px: Qt.fontFamilies().indexOf("Dogica Pixel") !== -1 ? "Dogica Pixel" : host.fontFamily
  function mix(a, b, k) { return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, 1) }
  readonly property color module: mix(bg, fg, 0.13)
  readonly property color line: mix(bg, fg, 0.08)

  implicitWidth: 660
  implicitHeight: 410

  property real bright: 0.5
  Process {
    id: brRead
    command: ["bash", "-c", "brightnessctl -m 2>/dev/null | head -1"]
    stdout: StdioCollector { onStreamFinished: { var f = text.split(","); if (f.length > 3) r.bright = parseFloat(f[3]) / 100 } }
  }
  onRiseChanged: if (rise > 0.99 && !brRead.running) brRead.running = true
  function setBright(x) { r.bright = Math.max(0.02, Math.min(1, x)); Quickshell.execDetached(["brightnessctl", "-q", "set", Math.round(r.bright * 100) + "%"]) }

  // блок цвета модуля
  component Block: Rectangle {
    radius: 6
    color: r.module
    border.width: 2
    border.color: r.line
  }
  // кнопка-значок: квадрат со скруглением цвета панели, значок акцентом
  component Btn: Rectangle {
    id: b
    property string icon
    property var cmd: []
    property int size: 34
    signal clicked()
    width: size; height: size; radius: 6
    color: ma.containsMouse ? r.mix(r.module, r.fg, 0.12) : r.mix(r.bg, r.fg, 0.07)
    border.width: 1; border.color: r.line
    Text { anchors.centerIn: parent; text: b.icon; color: r.acc; font.family: r.host.iconFamily; font.pixelSize: Math.round(b.size * 0.45) }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
      onClicked: { if (b.cmd.length) Quickshell.execDetached(b.cmd); b.clicked() } }
  }

  opacity: Math.min(1, rise * 2)
  transform: Translate { y: (1 - Math.min(1, r.rise * 1.4)) * 20 }

  // аватар и питание
  Block {
    x: 0; y: 0; width: 300; height: 228
    Rectangle {
      x: 18; y: 34; width: 160; height: 160; radius: 80
      color: r.mix(r.bg, r.fg, 0.07)
      border.width: 6; border.color: r.line
      Rectangle {
        anchors.fill: parent; anchors.margins: 12; radius: width / 2
        color: r.mix(r.bg, r.fg, 0.1)
        border.width: 2; border.color: r.acc
        clip: true
        Image {
          id: face
          anchors.fill: parent; anchors.margins: 3
          source: { var a = String(r.host.value("dashAvatar") || ""); if (!a) return ""; return "file://" + a.replace(/^~/, Quickshell.env("HOME")) }
          fillMode: Image.PreserveAspectCrop
          visible: status === Image.Ready
          layer.enabled: true
          layer.effect: MultiEffect { maskEnabled: true; maskSource: faceMask; maskThresholdMin: 0.5 }
        }
        Rectangle { id: faceMask; anchors.fill: face; radius: width / 2; visible: false; layer.enabled: true }
        Text { visible: face.status !== Image.Ready; anchors.centerIn: parent; text: "=^.^="; color: r.acc; font.family: r.px; font.pixelSize: 14 }
      }
    }
    Column {
      x: 214; y: 16; spacing: 8
      Btn { icon: "󰐥"; onClicked: { r.host.dashboardOpen = false; r.host.powerOpen = true } }
      Btn { icon: "󰍃"; cmd: ["omarchy-system", "logout"] }
      Btn { icon: "󰜉"; onClicked: { r.host.dashboardOpen = false; r.host.powerOpen = true } }
      Btn { icon: "󰌾"; cmd: ["omarchy-system-lock"] }
      Btn { icon: "󰏪"; cmd: ["omarchy-shell", "widgets", "toggleEdit"] }
    }
  }

  // приветствие, кнопки, плеер
  Block {
    x: 312; y: 0; width: 290; height: 228
    Column {
      anchors.horizontalCenter: parent.horizontalCenter; y: 26; spacing: 6
      Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Hello.."; color: r.acc; font.family: r.host.fontFamily; font.pixelSize: 15; font.italic: true }
      Text { anchors.horizontalCenter: parent.horizontalCenter; text: Quickshell.env("USER") || "user"; color: r.acc; font.family: r.host.fontFamily; font.pixelSize: 20; font.italic: true; font.weight: Font.DemiBold }
    }
    Row {
      anchors.horizontalCenter: parent.horizontalCenter; y: 100; spacing: 8
      Btn { icon: "󰉋"; size: 32; cmd: ["nautilus", "--new-window"] }
      Btn { icon: "󰍉"; size: 32; cmd: ["omarchy-menu", "toggle", "root"] }
      Btn { icon: "󰄀"; size: 32; cmd: ["omarchy-capture-screenshot"] }
      Btn { icon: "󰆍"; size: 32; cmd: ["omarchy-launch-terminal"] }
      Btn { icon: "󰂯"; size: 32; cmd: ["omarchy-shell", "omarchy.bluetooth", "toggle"] }
    }
    Row {
      anchors.horizontalCenter: parent.horizontalCenter; y: 160; spacing: 18
      readonly property var p: r.host.player
      Btn { icon: "󰒮"; size: 34; onClicked: if (parent.p) parent.p.previous() }
      Btn { icon: parent.p && parent.p.isPlaying ? "󰏤" : "󰐊"; size: 34; onClicked: if (parent.p) parent.p.togglePlaying() }
      Btn { icon: "󰒭"; size: 34; onClicked: if (parent.p) parent.p.next() }
    }
  }

  // яркость
  Block {
    x: 614; y: 0; width: 46; height: 228
    Btn { x: 6; y: 8; icon: "󰁝"; size: 34; onClicked: r.setBright(r.bright + 0.1) }
    Text { anchors.horizontalCenter: parent.horizontalCenter; y: 52; text: "󰃟"; color: r.acc; font.family: r.host.iconFamily; font.pixelSize: 15 }
    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter; y: 76; width: 8; height: 100; radius: 2
      color: r.mix(r.bg, r.fg, 0.07)
      Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: parent.height * r.bright; radius: 2; color: r.acc }
      MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor
        onPressed: function(m) { r.setBright(1 - m.y / height) }
        onPositionChanged: function(m) { if (pressed) r.setBright(1 - m.y / height) } }
    }
    Btn { x: 6; y: 186; icon: "󰁅"; size: 34; onClicked: r.setBright(r.bright - 0.1) }
  }

  // вклады GitHub
  Block {
    x: 0; y: 240; width: 660; height: 170
    clip: true
    ContribWidget {
      anchors.centerIn: parent
      host: r.host
      scale: Math.min(1, (parent.width - 30) / Math.max(1, implicitWidth))
    }
  }
}

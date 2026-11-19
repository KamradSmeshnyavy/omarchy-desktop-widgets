import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons as Commons

// Заставка Modern при входе в сеанс — по мотивам его Modern/boot/BootShell.qml (github.com/elifouts/Dotfiles, GPL-3.0;
// облик — v2/boot-*.png, boot.gif; код свой): чёрный экран, из него проявляются обои под размытием, три кольца
// вращаются навстречу, по центру «HYPRLAND» и «SESSION / INITIALIZING → READY»; слева сверху «BOOTSTRAP // LIVE» и
// «CAT // файл», справа сверху и слева снизу печатаются строки твоих конфигов (hypr/*.lua, тема); внизу черта.
// Показывается раз за вход (метка в $XDG_RUNTIME_DIR) у райса Modern, если bootIntro не выключен (панель настроек →
// Shell); повтор — IPC widgets bootIntro. Клики не перехватывает, клавиатуру не берёт. У остальных райсов при входе —
// заставка оверлея перехода Customizer (scripts/rice-transition.sh boot <имя райса>): размытые обои из чёрного.
Scope {
  id: boot
  required property var host

  readonly property bool enabled: host.rice !== "" && host.value("bootIntro") !== false
  readonly property string transition: Quickshell.env("HOME") + "/.config/omarchy/plugins/kamradsmeshnyavy.customizer/scripts/rice-transition.sh"
  readonly property string marker: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omarchy-modern-boot"

  property bool shown: false
  property real reveal: 0
  property real prog: 0
  property real exit: 0
  readonly property real closeT: 1 - exit
  readonly property real closeOpacity: Math.max(0.001, Math.min(1, closeT * 2.5))
  function phase(start, len) { return Math.max(0, Math.min(1, (prog - start) / len)) }

  // раз за вход: метки нет — показать и создать
  Process {
    id: check
    running: false
    command: ["sh", "-c", "test -e \"$1\" && echo seen || { touch \"$1\"; echo new; }", "sh", boot.marker]
    stdout: StdioCollector {
      onStreamFinished: {
        if (text.trim() !== "new") return
        if (boot.host.rice === "modern") boot.play(1800)
        else Quickshell.execDetached([boot.transition, "boot", boot.host.rice])
      }
    }
  }
  Timer { interval: 1500; running: true; onTriggered: if (boot.enabled) check.running = true }

  // строки конфигов
  readonly property var sources: [["hypr/hyprland.lua", "/.config/hypr/hyprland.lua"], ["hypr/looknfeel.lua", "/.config/hypr/looknfeel.lua"],
    ["hypr/bindings.lua", "/.config/hypr/bindings.lua"], ["hypr/autostart.lua", "/.config/hypr/autostart.lua"], ["theme/hyprland.lua", "/.local/state/omarchy/current/theme/hyprland.lua"]]
  property int src: 0
  readonly property int src2: (src + 1) % sources.length
  FileView { id: fileA; path: Quickshell.env("HOME") + boot.sources[boot.src][1]; printErrors: false }
  FileView { id: fileB; path: Quickshell.env("HOME") + boot.sources[boot.src2][1]; printErrors: false }
  function linesOf(t, n) {
    var l = String(t || "").split("\n").filter(function(x) { return x.trim() !== "" }).slice(0, n)
    return l.length ? l : ["hl.on(\"hyprland.start\", function()", "    hl.exec_cmd(\"omarchy-shell\")", "end)"]
  }
  readonly property var codeA: linesOf(fileA.text(), 26)
  readonly property var codeB: linesOf(fileB.text(), 14)
  property int lineA: 0
  property int charsA: 0
  property int lineB: 0
  property int charsB: 0

  function play(blackMs) {
    src = Math.floor(Math.random() * sources.length)
    fileA.reload(); fileB.reload()
    lineA = 0; charsA = 0; lineB = 0; charsB = 0
    reveal = 0; prog = 0; exit = 0
    shown = true
    blackTimer.interval = blackMs
    blackTimer.restart()
  }
  Timer { id: blackTimer; onTriggered: { revealAnim.start(); progAnim.start(); typing.start() } }
  NumberAnimation { id: revealAnim; target: boot; property: "reveal"; from: 0; to: 1; duration: 1150; easing.type: Easing.InOutCubic }
  // у него весь показ — 1,2 с; растянуто вдвое, чтобы строки успели напечататься
  NumberAnimation { id: progAnim; target: boot; property: "prog"; from: 0; to: 1; duration: 2400; easing.type: Easing.OutCubic; onFinished: exitAnim.start() }
  NumberAnimation { id: exitAnim; target: boot; property: "exit"; from: 0; to: 1; duration: 450; easing.type: Easing.InOutCubic; onFinished: { boot.shown = false; typing.stop() } }
  Timer {
    id: typing
    interval: 16; repeat: true
    onTriggered: {
      var a = boot.codeA[boot.lineA] || ""
      boot.charsA += 14
      if (boot.charsA > a.length + 10 && boot.lineA < boot.codeA.length - 1) { boot.lineA++; boot.charsA = 0 }
      var b = boot.codeB[boot.lineB] || ""
      boot.charsB += 18
      if (boot.charsB > b.length + 10 && boot.lineB < boot.codeB.length - 1) { boot.lineB++; boot.charsB = 0 }
    }
  }

  readonly property color fg: Commons.Color.foreground
  readonly property color bg: Commons.Color.background
  readonly property color accent: Commons.Color.accent
  function a(c, k) { return Qt.rgba(c.r, c.g, c.b, k) }
  readonly property string font: Qt.fontFamilies().indexOf("CodeNewRoman Nerd Font Propo") !== -1 ? "CodeNewRoman Nerd Font Propo"
    : Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : "monospace"

  Variants {
    model: Quickshell.screens
    PanelWindow {
      id: win
      required property var modelData
      screen: modelData
      visible: boot.shown
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "omarchy-boot"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      mask: Region {}
      readonly property real m: Math.min(width, height)

      Image {
        id: wall
        anchors.fill: parent
        visible: false
        source: boot.shown ? "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/current/background" : ""
        sourceSize.width: 1280
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
      }
      MultiEffect {
        anchors.fill: parent
        source: wall
        blurEnabled: true; blur: 1; blurMax: 64
        brightness: -0.22 * boot.closeT
        opacity: boot.reveal * boot.closeOpacity
        scale: 1.035 * boot.closeT + 0.025 * (1 - boot.reveal) * boot.closeT + (1 - boot.closeT)
      }
      Rectangle { anchors.fill: parent; color: "black"; opacity: (1 - boot.reveal) * boot.closeOpacity }
      Rectangle { anchors.fill: parent; color: boot.bg; opacity: 0.16 * boot.closeT }

      Item {
        anchors.fill: parent
        opacity: boot.closeOpacity * Math.min(1, boot.prog * 1.8)
        Rectangle {
          anchors.centerIn: parent
          width: win.m * 0.42; height: width; radius: width / 2
          color: "transparent"; border.width: 1; border.color: boot.a(boot.fg, 0.12)
          rotation: boot.prog * 18
        }
        Rectangle {
          anchors.centerIn: parent
          width: win.m * 0.29; height: width; radius: width / 2
          color: "transparent"; border.width: 2; border.color: boot.a(boot.accent, 0.26)
          rotation: -boot.prog * 28
        }
        Rectangle {
          anchors.centerIn: parent
          width: win.m * 0.16; height: width; radius: width / 2
          color: boot.a(boot.accent, 0.08); border.width: 1; border.color: boot.accent
          scale: 0.8 + boot.phase(0.2, 0.65) * 0.2
        }
        Text {
          anchors.centerIn: parent
          text: "HYPRLAND"
          color: boot.fg
          font.family: boot.font; font.pixelSize: Math.max(18, win.m * 0.022); font.letterSpacing: 5
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          y: parent.height / 2 + win.m * 0.09
          text: "SESSION / " + (boot.prog < 0.82 ? "INITIALIZING" : "READY")
          color: boot.prog < 0.82 ? boot.accent : boot.fg
          font.family: boot.font; font.pixelSize: 11; font.letterSpacing: 2
        }
      }

      Column {
        x: 56; y: 64
        spacing: 9
        opacity: boot.closeOpacity * boot.phase(0.06, 0.28)
        Text { text: "BOOTSTRAP // LIVE"; color: boot.accent; font.family: boot.font; font.pixelSize: 11; font.letterSpacing: 2 }
        Text { text: "CAT // " + boot.sources[boot.src][0]; color: boot.a(boot.fg, 0.5); font.family: boot.font; font.pixelSize: 10; font.letterSpacing: 1 }
      }

      // справа сверху: строки конфига печатаются, текущая — ярче и с «›»
      Item {
        anchors.right: parent.right; anchors.rightMargin: 56
        y: 64
        width: Math.min(parent.width * 0.34, 560)
        height: parent.height - 128
        clip: true
        opacity: boot.closeOpacity * boot.phase(0.12, 0.3)
        Repeater {
          model: boot.codeA.length
          Text {
            required property int index
            readonly property string line: boot.codeA[index] || ""
            width: parent.width; height: 14; y: index * 18
            elide: Text.ElideRight
            text: (index === boot.lineA ? "› " : "  ") + (index === boot.lineA ? line.slice(0, Math.min(boot.charsA, line.length)) : line)
            color: index === boot.lineA ? boot.fg : boot.a(boot.fg, 0.5)
            opacity: index > boot.lineA ? 0 : index === boot.lineA ? 1 : 0.38
            font.family: boot.font; font.pixelSize: 12
          }
        }
      }

      // слева снизу: второй файл с номерами строк
      Column {
        x: 56
        anchors.bottom: parent.bottom; anchors.bottomMargin: parent.height * 0.17
        width: Math.min(parent.width * 0.4, 620)
        spacing: 4
        opacity: boot.closeOpacity * boot.phase(0.16, 0.3)
        Repeater {
          model: boot.codeB.length
          Row {
            required property int index
            readonly property string line: boot.codeB[index] || ""
            spacing: 10
            opacity: index > boot.lineB ? 0 : index === boot.lineB ? 1 : 0.42
            Text { width: 22; text: (index < 9 ? "0" : "") + (index + 1); color: index === boot.lineB ? boot.fg : boot.a(boot.fg, 0.4); font.family: boot.font; font.pixelSize: 11 }
            Text { width: 12; text: index === boot.lineB ? "›" : ""; color: boot.fg; font.family: boot.font; font.pixelSize: 11 }
            Text {
              width: 560; elide: Text.ElideRight
              text: parent.index === boot.lineB ? parent.line.slice(0, Math.min(boot.charsB, parent.line.length)) : parent.line
              color: parent.index === boot.lineB ? boot.fg : boot.a(boot.fg, 0.55)
              font.family: boot.font; font.pixelSize: 11
            }
          }
        }
      }

      Rectangle {
        x: 56; width: parent.width - 112; height: 1
        anchors.bottom: parent.bottom; anchors.bottomMargin: parent.height * 0.04
        color: boot.a(boot.accent, 0.25)
        opacity: boot.closeOpacity * boot.phase(0.1, 0.4)
        transform: Scale { xScale: boot.phase(0.1, 0.6) }
      }
    }
  }
}

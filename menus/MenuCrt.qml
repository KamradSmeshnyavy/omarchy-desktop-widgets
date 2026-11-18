import QtQuick
import Quickshell
import ".."

// Меню Super+M Retro CRT — «Главное меню ЭВМ» (своё, в облике стиля Retro из elifouts/Dotfiles, GPL-3.0: его двойные
// рамки Box, текст Terminess капсом, «печать» с курсором █, включение трубки Tube). Нумерованный список разделов, как
// меню старой машины: 1–3 открывают раздел (сеть, bluetooth, звук), 4–7 — переключатели с [ВКЛ] / [ВЫКЛ], 8 — снимок
// экрана, 9 — Customizer, 0 — питание. Цифра на клавиатуре выбирает строку сразу, ↑↓ / j k и Enter — тоже, мышь —
// клик. Внизу строка «ВЫБОР 0-9 > _» с мигающим курсором. Раздел открывается в той же рамке, Esc — назад / закрыть.
MenuBase {
  id: m
  body: sbody
  CrtPal { id: cp }
  readonly property var items: [
    ["1", "wifi", "сеть", "page"], ["2", "bt", "bluetooth", "page"], ["3", "audio", "звук", "page"],
    ["4", "night", "ночной свет", "t"], ["5", "dnd", "не беспокоить", "t"], ["6", "awake", "не засыпать", "t"],
    ["7", "mic", "микрофон", "t"], ["8", "shot", "снимок экрана", "x"], ["9", "tweak", "настройка (customizer)", "x"],
    ["0", "power", "питание", "x"]]
  readonly property var titles: ({ wifi: "сеть", bt: "bluetooth", audio: "звук" })
  property int sel: 0
  onOpenChanged: if (open) sel = 0

  function on(id) {
    var s = m.st
    if (!s) return false
    return id === "night" ? s.night : id === "dnd" ? s.dnd : id === "awake" ? s.caffeine : id === "mic" ? !s.micMuted
      : id === "wifi" ? s.wifi : id === "bt" ? s.bt : false
  }
  function act(d) {
    if (d[3] === "page") { page = d[1]; return }
    if (d[1] === "night") m.st.toggleNight(); else if (d[1] === "dnd") m.st.toggleDnd(); else if (d[1] === "awake") m.st.toggleCaffeine()
    else if (d[1] === "mic") m.st.toggleMic()
    else if (d[1] === "shot") { m.close(); m.run(["omarchy-capture-screenshot"]) }
    else if (d[1] === "tweak") { m.close(); m.run(["omarchy-shell", "shell", "toggle", "kamradsmeshnyavy.customizer"]) }
    else { m.close(); m.host.powerOpen = true }
  }
  function keys(e) {
    if (m.page !== "") return false
    var i = items.findIndex(function(d) { return d[0] === e.text })
    if (i >= 0) { sel = i; act(items[i]); return true }
    if (e.key === Qt.Key_Down || e.text === "j") { sel = (sel + 1) % items.length; return true }
    if (e.key === Qt.Key_Up || e.text === "k") { sel = (sel + items.length - 1) % items.length; return true }
    if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { act(items[sel]); return true }
    return false
  }

  // мигание курсора (его Blink: 530 мс)
  property bool blink: true
  Timer { interval: 530; repeat: true; running: m.open; onTriggered: m.blink = !m.blink }

  CrtTube {
    id: frame
    pal: cp
    anchors.centerIn: parent
    width: 640
    height: m.page === "" ? 96 + m.items.length * 26 + 70 : 520
    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    t: m.k

    CrtBox {
      pal: cp
      anchors.fill: parent
      double: true
      title: m.page === "" ? "главное меню эвм" : (m.titles[m.page] || m.page)
      note: m.page === "" ? "esc-конец" : "esc-назад"
    }
    MouseArea { anchors.fill: parent }

    // ── главный вид: нумерованный список ──
    Item {
      anchors.fill: parent
      visible: m.page === ""
      CrtType {
        pal: cp; x: 26; y: 22
        caps: false
        text: (Quickshell.env("USER") || "user") + "  ·  выберите раздел:"
        color: cp.dim
      }
      Column {
        x: 26; y: 56
        width: frame.width - 52
        spacing: 2
        Repeater {
          model: m.items
          Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool cur: index === m.sel
            readonly property bool lit: m.on(modelData[1])
            width: parent.width; height: 24
            color: cur ? cp.accent : ra.containsMouse ? cp.low : "transparent"
            CrtType {
              pal: cp; x: 8; height: parent.height
              text: row.modelData[0] + ".  " + row.modelData[2] + (row.modelData[3] === "page" ? "  ›" : "")
              color: row.cur ? cp.bg : cp.fg
            }
            CrtType {
              visible: row.modelData[3] === "t" || row.modelData[3] === "page" && (row.modelData[1] === "wifi" || row.modelData[1] === "bt")
              type: false; pal: cp
              anchors.right: parent.right; anchors.rightMargin: 8; height: parent.height
              text: row.lit ? "[вкл]" : "[выкл]"
              color: row.cur ? cp.bg : row.lit ? cp.accent : cp.dim
            }
            MouseArea { id: ra; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: m.sel = row.index; onClicked: m.act(row.modelData) }
          }
        }
      }
      Rectangle { x: 26; y: frame.height - 58; width: frame.width - 52; height: 1; color: cp.low }
      Row {
        x: 26; y: frame.height - 50
        height: 24; spacing: 0
        CrtType { pal: cp; height: parent.height; text: "выбор 0-9 > "; color: cp.fg }
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 9; height: 16; color: cp.accent; opacity: m.blink ? 1 : 0 }
      }
      CrtType {
        type: false; pal: cp
        anchors.right: parent.right; anchors.rightMargin: 26; y: frame.height - 50; height: 24
        text: "↑↓ enter"; color: cp.dim; font.pixelSize: cp.size - 3
      }
    }

    // ── раздел ──
    SectionBody {
      id: sbody
      visible: m.page !== ""
      x: 22; y: 24; width: frame.width - 44; height: frame.height - 48
      md: m.md; page: m.page
      ink: cp.fg; litFill: cp.accent; litInk: cp.bg; hoverFill: cp.low; line: cp.line
      radius: 0; size: 13; rowH: 30; field: cp.a(cp.accent, 0.06); font: cp.font; bar: "blocks"
      textOn: "[x] "; textOff: "[ ] "
    }
  }
}

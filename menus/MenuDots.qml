import QtQuick
import "../dotmatrix" as DotMatrix

// Меню Super+M DOT-MATRIX — «приборная панель» (свой, в облике DOT-MATRIX / Nothing: чёрная панель, тонкие линии,
// точечный шрифт, один красный сигнал — DotMatrix.Palette). Слева — круглая ручка-селектор с метками WIFI · BT · AUDIO ·
// SYS по кругу: колесо, [ / ] или клик по метке поворачивают ручку и переключают раздел; справа — «точечный дисплей»
// раздела (списки), внизу — ряд рычажков-тумблеров (night, silence, awake, mic) и красный LED; кнопки lock / power.
// Стрелки / Tab / Enter (KeyNav), Esc — закрыть.
MenuBase {
  id: m
  readonly property var pal: DotMatrix.Palette
  readonly property var modes: ["wifi", "bt", "audio", "sys"]
  readonly property string cur: page === "" ? "sys" : page
  readonly property int ci: modes.indexOf(cur)
  function go(i) { i = (i + modes.length) % modes.length; page = i === 3 ? "" : modes[i] }
  function back() { return false }
  function keys(e) {
    if (e.key === Qt.Key_BracketRight) { go(ci + 1); return true }
    if (e.key === Qt.Key_BracketLeft) { go(ci - 1); return true }
    return false
  }
  component Lever: Item {
    id: lv
    property string label: ""
    property bool on: false
    signal hit()
    width: 92; height: 92
    Rectangle {
      x: 32; y: 6; width: 28; height: 56; radius: 14; color: m.pal.surface; border.width: 1; border.color: m.pal.line
      Rectangle { x: 4; width: 20; height: 20; radius: 10; y: lv.on ? 4 : 32; color: lv.on ? m.pal.fg : m.pal.muted; Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutBack } } }
    }
    Text { anchors.horizontalCenter: parent.horizontalCenter; y: 70; text: lv.label.toUpperCase(); color: lv.on ? m.pal.fg : m.pal.muted; font.family: m.pal.fontMono; font.pixelSize: 9; font.letterSpacing: 1.4 }
    TapHandler { onTapped: lv.hit() }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
  }

  Rectangle {
    id: panel
    width: 800; height: 420; radius: 28
    anchors.centerIn: parent
    color: m.pal.bg; border.width: 1; border.color: m.pal.line
    opacity: m.k
    MouseArea { anchors.fill: parent }
    WheelHandler { onWheel: function(e) { m.go(m.ci + (e.angleDelta.y < 0 ? 1 : -1)) } }
    Row {
      x: 26; y: 22; spacing: 8
      Rectangle { width: 7; height: 7; radius: 3.5; color: m.pal.signal; anchors.verticalCenter: parent.verticalCenter }
      Text { text: "CONTROL · " + m.cur.toUpperCase(); color: m.pal.muted; font.family: m.pal.fontMono; font.pixelSize: 10; font.letterSpacing: 1.6 }
    }
    // ручка-селектор
    Item {
      id: knob
      x: 30; y: 60; width: 220; height: 220
      Repeater {
        model: m.modes
        Text {
          required property var modelData
          required property int index
          readonly property real ang: (-60 + index * 40) * Math.PI / 180
          x: 110 + Math.sin(ang) * 100 - width / 2; y: 110 - Math.cos(ang) * 100 - height / 2
          text: modelData.toUpperCase(); color: m.ci === index ? m.pal.fg : m.pal.muted
          font.family: m.pal.fontMono; font.pixelSize: 10; font.letterSpacing: 1.4
          TapHandler { onTapped: m.go(index) }
          HoverHandler { cursorShape: Qt.PointingHandCursor }
        }
      }
      Rectangle {
        anchors.centerIn: parent; width: 140; height: 140; radius: 70; color: m.pal.surface; border.width: 1; border.color: m.pal.line
        rotation: -60 + m.ci * 40
        Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 10; width: 6; height: 24; radius: 3; color: m.pal.signal }
        Repeater { model: 24; Rectangle { required property int index; readonly property real a: index / 24 * Math.PI * 2
          x: 70 + Math.sin(a) * 58 - 1.5; y: 70 - Math.cos(a) * 58 - 1.5; width: 3; height: 3; radius: 1.5; color: m.pal.unlit } }
      }
    }
    // дисплей
    Rectangle {
      x: 280; y: 56; width: 494; height: 236; radius: 18; color: m.pal.surface; border.width: 1; border.color: m.pal.line; clip: true
      Text {
        visible: m.cur === "sys"; anchors.centerIn: parent
        text: Qt.formatTime(new Date(), "HH:mm"); color: m.pal.fg; font.family: m.pal.fontDot; font.pixelSize: 96
      }
      SectionBody {
        visible: m.cur !== "sys"
        x: 12; y: 12; width: parent.width - 24; height: parent.height - 24
        md: m.md; page: m.cur
        ink: m.pal.fg; dim: m.pal.dim; litFill: m.pal.fg; litInk: m.pal.bg; line: m.pal.line; radius: 10; font: m.pal.fontMono; size: 11; rowH: 34; field: m.pal.bg
      }
    }
    // тумблеры
    Row {
      x: 24; y: 312; spacing: 6
      Lever { label: "night"; on: !!m.st && m.st.night; onHit: m.st.toggleNight() }
      Lever { label: "silence"; on: !!m.st && m.st.dnd; onHit: m.st.toggleDnd() }
      Lever { label: "awake"; on: !!m.st && m.st.caffeine; onHit: m.st.toggleCaffeine() }
      Lever { label: "mic"; on: !!m.st && !m.st.micMuted; onHit: m.st.toggleMic() }
    }
    Row {
      anchors.right: parent.right; anchors.rightMargin: 26; y: 336; spacing: 10
      Repeater {
        model: [["LOCK", 0], ["SHOT", 1], ["POWER", 2]]
        Rectangle {
          required property var modelData
          width: 90; height: 40; radius: 20; color: bh.hovered ? (modelData[1] === 2 ? m.pal.signal : m.pal.fg) : "transparent"; border.width: 1; border.color: modelData[1] === 2 ? m.pal.signal : m.pal.line
          Text { anchors.centerIn: parent; text: modelData[0]; color: bh.hovered ? m.pal.bg : (modelData[1] === 2 ? m.pal.signal : m.pal.fg); font.family: m.pal.fontMono; font.pixelSize: 10; font.letterSpacing: 1.4 }
          HoverHandler { id: bh; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: { m.close(); if (modelData[1] === 0) m.run(["omarchy-system-lock"]); else if (modelData[1] === 1) m.run(["omarchy-capture-screenshot"]); else m.host.powerOpen = true } }
        }
      }
    }
  }
}

import QtQuick

// Полоса таймера и будильника под карточкой плеера (Super+Alt+M), общая для всех видов плеера: скруглённое стекло
// цветами темы. Таймер — чипы 5 / 10 / 25 / 45 мин, во время счёта — обратный отсчёт, полоска, +5 и ✕. Будильник —
// время (колесо над часами / минутами — ±1 ч / ±5 мин, клик — ±1) и переключатель. Звонок — его колокольчик
// (по мотивам Modern/bar/Alarm.qml из elifouts/Dotfiles, GPL-3.0): прыгает и качается, «Time's up», ✕ — тишина.
Rectangle {
  id: st
  required property var host
  required property var ts
  readonly property color fg: host.foreground
  readonly property color bg: host.background
  readonly property color accent: host.accent
  function a(c, k) { return Qt.rgba(c.r, c.g, c.b, k) }
  readonly property string font: Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : "monospace"

  implicitHeight: col.implicitHeight + 20
  radius: 14
  color: a(bg, 0.96)
  border.width: 1
  border.color: a(fg, 0.08)

  component Chip: Rectangle {
    id: c
    property var s: null   // вложенный компонент не видит id st — передаётся снаружи
    property string label
    property bool lit: false
    signal hit()
    width: cl.implicitWidth + 16; height: 24; radius: 8
    color: lit ? c.s.accent : ca.containsMouse ? c.s.a(c.s.fg, 0.14) : c.s.a(c.s.fg, 0.07)
    Text { id: cl; anchors.centerIn: parent; text: c.label; font.family: c.s.font; font.pixelSize: 11; color: c.lit ? c.s.bg : c.s.fg }
    MouseArea { id: ca; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: c.hit() }
  }

  Column {
    id: col
    x: 14; y: 10
    width: st.width - 28
    spacing: 8

    // звонок
    Item {
      visible: st.ts.ringing
      width: parent.width; height: 40
      Text {
        id: bell
        x: 2; anchors.verticalCenter: parent.verticalCenter
        text: "󰀠"; font.family: st.font; font.pixelSize: 24; color: st.accent
        transform: Translate { id: hop }
        ParallelAnimation {
          running: st.ts.ringing
          loops: Animation.Infinite
          onStopped: { hop.y = 0; bell.rotation = 0 }
          SequentialAnimation {
            NumberAnimation { target: hop; property: "y"; to: -5; duration: 180; easing.type: Easing.OutQuad }
            NumberAnimation { target: hop; property: "y"; to: 0; duration: 420; easing.type: Easing.OutBounce }
            PauseAnimation { duration: 350 }
          }
          SequentialAnimation {
            SequentialAnimation {
              loops: 4
              NumberAnimation { target: bell; property: "rotation"; to: 12; duration: 60; easing.type: Easing.InOutSine }
              NumberAnimation { target: bell; property: "rotation"; to: -12; duration: 60; easing.type: Easing.InOutSine }
            }
            NumberAnimation { target: bell; property: "rotation"; to: 0; duration: 120; easing.type: Easing.OutQuad }
            PauseAnimation { duration: 350 }
          }
        }
      }
      Column {
        x: 40; anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 80
        Text { text: "Time's up"; font.family: st.font; font.pixelSize: 13; color: st.fg }
        Text { width: parent.width; elide: Text.ElideRight; text: st.ts.ringLabel; font.family: st.font; font.pixelSize: 10; color: st.a(st.fg, 0.55) }
      }
      Chip { s: st; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; label: "󰅖"; onHit: st.ts.dismiss() }
    }

    // таймер
    Item {
      width: parent.width; height: 26
      Text { anchors.verticalCenter: parent.verticalCenter; text: "󰔛  timer"; font.family: st.font; font.pixelSize: 12; color: st.a(st.fg, 0.7) }
      Row {
        visible: !st.ts.running
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        spacing: 5
        Repeater { model: [5, 10, 25, 45]; Chip { s: st; required property int modelData; label: modelData + "m"; onHit: st.ts.start(modelData) } }
      }
      Row {
        visible: st.ts.running
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Text { anchors.verticalCenter: parent.verticalCenter; text: st.ts.fmt(st.ts.remaining); font.family: st.font; font.pixelSize: 15; font.bold: true; color: st.fg }
        Chip { s: st; label: "+5"; onHit: st.ts.add(5) }
        Chip { s: st; label: "󰅖"; onHit: st.ts.cancel() }
      }
    }
    Rectangle {
      visible: st.ts.running
      width: parent.width; height: 3; radius: 1.5
      color: st.a(st.fg, 0.1)
      Rectangle { width: parent.width * st.ts.frac; height: parent.height; radius: parent.radius; color: st.accent }
    }

    // будильник
    Item {
      width: parent.width; height: 26
      Text { anchors.verticalCenter: parent.verticalCenter; text: "󰀠  alarm"; font.family: st.font; font.pixelSize: 12; color: st.a(st.fg, 0.7) }
      Row {
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        Row {
          anchors.verticalCenter: parent.verticalCenter
          Repeater {
            model: [[0, 60], [1, 5]]
            Text {
              required property var modelData
              text: (modelData[0] === 0 ? "" : ":") + st.ts.alarm.split(":")[modelData[0]]
              font.family: st.font; font.pixelSize: 15; font.bold: st.ts.alarmOn
              color: st.ts.alarmOn ? st.fg : st.a(st.fg, 0.45)
              MouseArea {
                anchors.fill: parent; anchors.margins: -4
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.SizeVerCursor
                onClicked: m => st.ts.shiftAlarm((m.button === Qt.RightButton ? -1 : 1) * (parent.modelData[0] === 0 ? 60 : 1))
                onWheel: w => st.ts.shiftAlarm((w.angleDelta.y > 0 ? 1 : -1) * parent.modelData[1])
              }
            }
          }
        }
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: 34; height: 18; radius: 9
          color: st.ts.alarmOn ? st.accent : st.a(st.fg, 0.14)
          Rectangle { width: 12; height: 12; radius: 6; y: 3; x: st.ts.alarmOn ? parent.width - 15 : 3; color: st.ts.alarmOn ? st.bg : st.a(st.fg, 0.7)
            Behavior on x { NumberAnimation { duration: 160 } } }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: st.ts.toggleAlarm() }
        }
      }
    }
  }
}

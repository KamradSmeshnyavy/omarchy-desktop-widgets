import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Wayland

// Дашборд райса Cozy Room — сама комната (свой). Открывается dashboardOpen, когда dashStyle — room. Фон — room/dash.png
// темы (пустая комната 320 × 180, увеличена без сглаживания), предметы поверх — по местам из room.json (dash):
//   окно   — небо по времени суток (утро / день / вечер / ночь со звёздами), огни города, у «Ливня» — дождь;
//   часы   — время (клик — календарь);
//   полка  — книги: открытые окна, корешок цветом по приложению (клик — к окну);
//   кружка — пар растёт с загрузкой CPU;      растение — вянет, когда диск заполнен больше чем на 90 %;
//   кот    — спит, пока память свободна, и ходит по комнате, когда занято больше 80 %;
//   лампа  — свет по заряду батареи, мерцает ниже 20 %;   радио — плеер (клик — плеер Super+Alt+M), ноты, пока играет;
//   дверь  — меню выключения.
// Внизу — записка с подписью предмета под мышью или под рамкой клавиатуры. Клавиатура — KeyNav, Esc / клик мимо — закрыть.
PanelWindow {
  id: win
  required property var host
  readonly property bool on: host.dashboardOpen && String(host.value("dashStyle")) === "room"
  RoomPal { id: rp }

  property real t: 0
  visible: t > 0.001
  screen: host.focusedScreen
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  WlrLayershell.namespace: "omarchy-dashboard"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: on ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  onOnChanged: {
    if (on) { closing.stop(); opening.restart(); Hyprland.refreshToplevels() }
    else { opening.stop(); closing.restart() }
  }
  NumberAnimation { id: opening; target: win; property: "t"; to: 1; duration: 420; easing.type: Easing.OutCubic }
  NumberAnimation { id: closing; target: win; property: "t"; to: 0; duration: 200; easing.type: Easing.InCubic }
  function close() { host.dashboardOpen = false }

  SysStats { id: ss; live: win.on }
  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: win.on; triggeredOnStart: true; onTriggered: win.now = new Date() }
  readonly property var battery: UPower.displayDevice
  readonly property bool hasBattery: !!battery && battery.isLaptopBattery
  readonly property real charge: hasBattery ? battery.percentage : 1
  readonly property var player: host.player
  readonly property var dm: rp.dash || ({ w: 320, h: 180, scale: 2, window: [22, 22, 84, 64], clock: [128, 26], shelf: [186, 54, 118],
    desk: [150, 116, 160], radio: [160, 98], plant: [214, 100], mug: [188, 100], lamp: [272, 102], door: [112, 92, 22, 50], floor: 142, cat: [30, 130] })
  property string caption: ""
  readonly property int hour: now.getHours()
  function hash(s) { var h = 0; s = String(s || ""); for (var i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0; return h }

  Rectangle { anchors.fill: parent; color: "black"; opacity: 0.55 * win.t }
  MouseArea { anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: win.close() }

  FocusScope {
    anchors.fill: parent
    focus: win.on
    Keys.onPressed: function(e) {
      if (e.key === Qt.Key_Escape) { win.close(); e.accepted = true; return }
      if (keyNav.handle(e)) e.accepted = true
    }

    Item {
      id: page
      // комната: кратно 320 × 180, сколько влезает
      readonly property int sc: Math.max(2, Math.floor(Math.min((win.width - 120) / win.dm.w, (win.height - 220) / win.dm.h)))
      readonly property int k: sc * win.dm.scale          // пиксель спрайта предмета
      width: win.dm.w * sc; height: win.dm.h * sc + 96
      anchors.centerIn: parent
      opacity: win.t
      transform: Translate { y: (1 - win.t) * 30 }

      // рама вокруг комнаты
      RoomWood { pal: rp; x: -14; y: -14; width: page.width + 28; height: win.dm.h * page.sc + 28; plank: 0; pad: 0 }
      MouseArea { x: 0; y: 0; width: page.width; height: win.dm.h * page.sc }

      Item {
        id: room
        width: win.dm.w * page.sc; height: win.dm.h * page.sc
        clip: true
        function u(v) { return v * page.sc }

        // ── окно: небо, город, дождь (под фоном комнаты не нарисованы — рисуем поверх стекла) ──
        Item {
          id: sky
          x: room.u(win.dm.window[0]); y: room.u(win.dm.window[1]); width: room.u(win.dm.window[2]); height: room.u(win.dm.window[3])
          clip: true
          readonly property color skyTop: win.hour < 6 || win.hour >= 21 ? "#0b1224" : win.hour < 9 ? "#f0a878" : win.hour < 18 ? "#8fc4ec" : "#4a3a78"
          readonly property color skyLow: win.hour < 6 || win.hour >= 21 ? rp.night : win.hour < 9 ? "#ffd8a8" : win.hour < 18 ? "#d8eef8" : "#e07860"
          Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0; color: rp.rain ? rp.night : sky.skyTop } GradientStop { position: 1; color: rp.rain ? rp.mix(rp.night, rp.cyan, 0.2) : sky.skyLow } } }
          Repeater {   // звёзды ночью
            model: (win.hour < 6 || win.hour >= 21) && !rp.rain ? 18 : 0
            Rectangle { required property int index; x: (index * 53) % sky.width; y: (index * 37) % (sky.height * 0.55); width: page.sc; height: page.sc; color: "#fff6d8"; opacity: 0.5 + (index % 3) * 0.2; antialiasing: false }
          }
          Repeater {   // город
            model: 10
            Rectangle {
              required property int index
              readonly property int hh: [10, 22, 15, 28, 12, 19, 25, 9, 17, 21][index]
              x: index * room.u(9); y: sky.height - room.u(hh); width: room.u(7); height: room.u(hh)
              color: rp.ink; antialiasing: false
              Repeater {
                model: Math.floor(parent.hh / 5)
                Rectangle { required property int index; x: page.sc * 3; y: page.sc * (3 + index * 5); width: page.sc; height: page.sc; antialiasing: false
                  color: rp.lamp; visible: (win.hash(String(parent.parent.index) + index) % 3) === 0 && (win.hour >= 17 || win.hour < 8) }
              }
            }
          }
          Repeater {   // дождь
            model: rp.rain ? 34 : 0
            Rectangle {
              required property int index
              x: (index * 37) % sky.width
              width: page.sc; height: page.sc * 3; color: rp.cyan; antialiasing: false
              NumberAnimation on y { running: win.on; loops: Animation.Infinite; from: -20 - (index * 23) % sky.height; to: sky.height; duration: 900 + (index * 47) % 500 }
            }
          }
        }

        // фон комнаты (окно в нём — рама и перекладины поверх неба: стекло в dash.png сплошное, поэтому — маска не нужна,
        // небо рисуется поверх фона, а рама — второй раз ниже)
        Image { anchors.fill: parent; source: rp.sprite("dash"); smooth: false; z: -1 }
        // рама и перекладины окна поверх неба
        Rectangle { x: sky.x + sky.width / 2 - page.sc; y: sky.y; width: page.sc * 2; height: sky.height; color: rp.wood; antialiasing: false }
        Rectangle { x: sky.x; y: sky.y + sky.height / 2 - page.sc; width: sky.width; height: page.sc * 2; color: rp.wood; antialiasing: false }

        // ── книги-окна на полке ──
        Row {
          id: books
          x: room.u(win.dm.shelf[0] + 10); anchors.bottom: parent.top; anchors.bottomMargin: -room.u(win.dm.shelf[1])
          spacing: page.sc
          Repeater {
            model: Hyprland.toplevels.values.slice(0, 14)
            Rectangle {
              id: bk
              required property var modelData
              readonly property string app: String(modelData.lastIpcObject && modelData.lastIpcObject.class || modelData.appId || "")
              width: room.u(6); height: room.u(12 + win.hash(app) % 5)
              anchors.bottom: parent.bottom
              color: rp.bookColors[win.hash(app) % rp.bookColors.length]
              border.width: page.sc; border.color: rp.ink; antialiasing: false
              transform: Translate { y: bh.containsMouse || keyNav.current === bh ? -page.sc * 3 : 0 }
              Rectangle { x: page.sc; y: page.sc * 3; width: parent.width - page.sc * 2; height: page.sc; color: rp.alpha("#ffffff", 0.3); antialiasing: false }
              MouseArea {
                id: bh
                anchors.fill: parent
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                readonly property string caption: "Книга «" + (bk.modelData.title || bk.app) + "» — стол " + (bk.modelData.workspace ? bk.modelData.workspace.id : "?") + ". Клик — открыть окно."
                onContainsMouseChanged: if (containsMouse) win.caption = caption
                onClicked: { Quickshell.execDetached(["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({ window = 'address:0x" + bk.modelData.address + "' }))"]); win.close() }
              }
            }
          }
        }

        // ── предметы ──
        // свет лампы — под предметами
        Rectangle {
          readonly property real r: room.u(30) * (0.6 + 0.4 * win.charge)
          x: room.u(win.dm.lamp[0] + 7) - r; y: room.u(win.dm.lamp[1] + 4) - r
          width: r * 2; height: r * 2; radius: r
          color: rp.alpha(rp.lamp, 0.16 * (0.4 + 0.6 * win.charge))
          SequentialAnimation on opacity {
            running: win.on && win.charge < 0.2; loops: Animation.Infinite
            NumberAnimation { to: 0.4; duration: 120 } NumberAnimation { to: 1; duration: 200 } PauseAnimation { duration: 700 }
          }
        }

        RoomThing {
          pal: rp; cell: page.sc; k: page.k
          onHovered: function(c) { win.caption = c }
          sprite: "clock"; at: win.dm.clock
          caption: "Часы: " + Qt.formatTime(win.now, "HH:mm") + ", " + Qt.formatDate(win.now, "d MMMM") + ". Клик — календарь."
          onHit: { win.close(); win.host.settingsSection = "calendar"; win.host.settingsOpen = true }
        }
        RoomThing {
          pal: rp; cell: page.sc; k: page.k
          onHovered: function(c) { win.caption = c }
          sprite: "radio"; at: win.dm.radio
          caption: win.player && win.player.trackTitle ? "Радио: «" + win.player.trackTitle + "»" + (win.player.trackArtist ? " — " + win.player.trackArtist : "") + ". Клик — плеер." : "Радио молчит. Клик — плеер."
          onHit: { win.close(); win.host.playerOpen = true }
        }
        RoomThing {
          pal: rp; cell: page.sc; k: page.k
          onHovered: function(c) { win.caption = c }
          id: mug
          sprite: ss.cpu > 0.08 ? "mug" : "mug-cold"; at: win.dm.mug
          caption: "Кружка: процессор занят на " + Math.round(ss.cpu * 100) + "%, внутри " + Math.round(ss.temp * 100) + "°."
        }
        RoomThing {
          pal: rp; cell: page.sc; k: page.k
          onHovered: function(c) { win.caption = c }
          sprite: ss.disk > 0.9 ? "plant-dry" : "plant"; at: win.dm.plant
          caption: ss.disk > 0.9 ? "Растение вянет: диск заполнен на " + Math.round(ss.disk * 100) + "%." : "Растение свежее: диск заполнен на " + Math.round(ss.disk * 100) + "%."
        }
        RoomThing {
          pal: rp; cell: page.sc; k: page.k
          onHovered: function(c) { win.caption = c }
          sprite: "lamp"; at: win.dm.lamp
          caption: win.hasBattery ? "Лампа: заряд " + Math.round(win.charge * 100) + "%" + (win.battery.state === UPowerDeviceState.Charging ? ", заряжается." : ".") : "Лампа: от сети, светит ровно."
          onHit: { win.close(); win.host.settingsSection = "power"; win.host.settingsOpen = true }
        }
        // дверь — область, нарисована в фоне
        MouseArea {
          x: room.u(win.dm.door[0]); y: room.u(win.dm.door[1]); width: room.u(win.dm.door[2]); height: room.u(win.dm.door[3])
          hoverEnabled: true; cursorShape: Qt.PointingHandCursor
          readonly property string caption: "Дверь: уйти — блокировка, сон, выключение."
          onContainsMouseChanged: if (containsMouse) win.caption = caption
          onClicked: { win.close(); win.host.powerOpen = true }
        }

        // пар над кружкой: клеток тем больше, чем занятее процессор
        Repeater {
          model: Math.round(ss.cpu * 6)
          Rectangle {
            required property int index
            width: page.sc * 2; height: page.sc * 2; color: rp.alpha(rp.text, 0.55); antialiasing: false
            x: mug.x + page.sc * (4 + (index % 3) * 3)
            SequentialAnimation on y {
              running: win.on; loops: Animation.Infinite
              NumberAnimation { from: mug.y; to: mug.y - page.sc * 18; duration: 1400 + index * 180 }
            }
            SequentialAnimation on opacity {
              running: win.on; loops: Animation.Infinite
              NumberAnimation { from: 0.9; to: 0; duration: 1400 + index * 180 }
            }
          }
        }
        // ноты над радио, пока играет
        Repeater {
          model: win.player && win.player.isPlaying ? 3 : 0
          Text {
            required property int index
            text: "♪"; color: rp.lamp; font.pixelSize: page.sc * 8
            x: room.u(win.dm.radio[0]) + index * page.sc * 7
            SequentialAnimation on y {
              running: win.on; loops: Animation.Infinite
              PauseAnimation { duration: index * 500 }
              NumberAnimation { from: room.u(win.dm.radio[1]); to: room.u(win.dm.radio[1] - 30); duration: 1800 }
            }
            SequentialAnimation on opacity {
              running: win.on; loops: Animation.Infinite
              PauseAnimation { duration: index * 500 }
              NumberAnimation { from: 1; to: 0; duration: 1800 }
            }
          }
        }

        // кот: спит, пока память свободна; занято > 80 % — ходит туда-сюда
        Item {
          id: cat
          readonly property bool busy: ss.mem > 0.8
          property real px: room.u(win.dm.cat[0])
          y: room.u(win.dm.cat[1]) - (busy ? page.k : 0)
          x: px
          width: catImg.width; height: catImg.height
          Image { id: catImg; source: rp.sprite(cat.busy ? "cat" : "cat-sleep"); smooth: false; width: sourceSize.width * page.k; height: sourceSize.height * page.k; mirror: catWalk.back }
          SequentialAnimation on px {
            id: catWalk
            property bool back: false
            running: win.on && cat.busy; loops: Animation.Infinite
            ScriptAction { script: catWalk.back = false }
            NumberAnimation { to: room.u(90); duration: 4000 }
            ScriptAction { script: catWalk.back = true }
            NumberAnimation { to: room.u(20); duration: 4000 }
          }
          MouseArea {
            anchors.fill: parent; anchors.margins: -page.sc * 2
            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            readonly property string caption: cat.busy ? "Кот бегает: память занята на " + Math.round(ss.mem * 100) + "%." : "Кот спит: память занята на " + Math.round(ss.mem * 100) + "%."
            onContainsMouseChanged: if (containsMouse) win.caption = caption
            onClicked: win.caption = caption + " Мур."
          }
        }
      }

      // ── записка-подпись ──
      RoomNote {
        pal: rp
        tilt: -0.8
        x: 40; y: win.dm.h * page.sc + 30
        width: page.width - 80; height: 56
        pad: 10
        Text {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width; elide: Text.ElideRight
          text: (keyNav.current && keyNav.current.caption ? keyNav.current.caption : win.caption)
            || "Наведите на предмет — расскажу, что с ним. Стрелки и Enter тоже работают."
          color: rp.paperink
          font.family: rp.font; font.pixelSize: 20
        }
      }
    }

    KeyNav { id: keyNav; anchors.fill: parent; z: 999; scope: room; active: win.on; ring: rp.lamp }
  }
}

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import ".."

// Меню Super+M райса Quest — командное меню ролевой игры (своё). Сверху окно отряда: герой, LV по аптайму, HP —
// батарея, MP — память. Слева — команды с рукой-курсором: СЕТЬ, BLUETOOTH, ЗВУК открывают раздел в правом окне;
// «заклинания» (ночной свет, не беспокоить, не засыпать, микрофон) переключаются по Enter; СНИМОК, НАСТРОЙКИ,
// ВЫХОД (меню выключения). Справа — окно подробностей выбранной команды, снизу — подсказки клавиш.
// ↑↓ / j k — команда, Enter / → / l — выбрать, Esc — назад из раздела / закрыть; мышь — наведение и клик.
// Окна раскрываются по очереди сверху вниз, как диалоги в игре.
MenuBase {
  id: m
  body: sbody
  QuestPal { id: qp }
  // [id, надпись, вид: page — раздел, spell — переключатель, act — действие]
  readonly property var items: [
    ["wifi", "СЕТЬ", "page"], ["bt", "BLUETOOTH", "page"], ["audio", "ЗВУК", "page"],
    ["night", "НОЧЬ", "spell"], ["dnd", "ТИШИНА", "spell"], ["awake", "БДЕНИЕ", "spell"], ["mic", "ГОЛОС", "spell"],
    ["shot", "СНИМОК", "act"], ["tweak", "НАСТРОЙКИ", "act"], ["power", "ВЫХОД", "act"]]
  // описание команды в окне подробностей
  readonly property var about: ({
    wifi: "Связь с миром. Сети рядом, пароль, DNS.", bt: "Призвать устройства: наушники, мышь, клавиатуру.",
    audio: "Громкость, выход и микрофон.", night: "Заклинание тёплого света для глаз.",
    dnd: "Заклинание тишины: уведомления не тревожат.", awake: "Заклинание бдения: экран не гаснет и не спит.",
    mic: "Голос героя: включить или заглушить микрофон.", shot: "Запечатлеть экран.",
    tweak: "Открыть Customizer: облик, анимации, обои.", power: "Покинуть игру: блокировка, сон, выход." })
  property int sel: 0
  onOpenChanged: if (open && page === "") sel = 0
  // раздел по openSettingsSection: рука-курсор встаёт на его команду
  onPageChanged: { var i = items.findIndex(function(d) { return d[0] === page }); if (i >= 0) sel = i }
  readonly property var cur: items[sel]

  function on(id) {
    var s = m.st
    if (!s) return false
    return id === "night" ? s.night : id === "dnd" ? s.dnd : id === "awake" ? s.caffeine : id === "mic" ? !s.micMuted
      : id === "wifi" ? s.wifi : id === "bt" ? s.bt : id === "audio" ? !s.muted : false
  }
  function act(d) {
    if (d[2] === "page") { page = d[0]; return }
    var s = m.st
    if (d[0] === "night") s.toggleNight(); else if (d[0] === "dnd") s.toggleDnd(); else if (d[0] === "awake") s.toggleCaffeine()
    else if (d[0] === "mic") s.toggleMic()
    else if (d[0] === "shot") { m.close(); m.run(["omarchy-capture-screenshot"]) }
    else if (d[0] === "tweak") { m.close(); m.run(["omarchy-shell", "shell", "toggle", "kamradsmeshnyavy.customizer"]) }
    else { m.close(); m.host.powerOpen = true }
  }
  function keys(e) {
    if (m.page !== "") return false
    if (e.key === Qt.Key_Down || e.text === "j") { sel = (sel + 1) % items.length; return true }
    if (e.key === Qt.Key_Up || e.text === "k") { sel = (sel + items.length - 1) % items.length; return true }
    if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Right || e.text === "l") { act(items[sel]); return true }
    return false
  }

  // ── данные отряда ──
  property real uptime: 0
  property real mem: 0
  Timer {
    interval: 4000; repeat: true; running: m.open; triggeredOnStart: true
    onTriggered: if (!probe.running) probe.running = true
  }
  property var probe: Process {
    command: ["sh", "-c", "cut -d' ' -f1 /proc/uptime; awk '/^MemTotal|^MemAvailable/{printf \"%s \", $2}' /proc/meminfo"]
    stdout: StdioCollector {
      onStreamFinished: {
        var l = text.trim().split("\n")
        m.uptime = Number(l[0]) || 0
        var f = String(l[1] || "").trim().split(/\s+/)
        if (Number(f[0]) > 0) m.mem = 1 - Number(f[1]) / Number(f[0])
      }
    }
  }
  readonly property var battery: UPower.displayDevice
  readonly property real hp: battery && battery.isLaptopBattery ? battery.percentage : 1

  readonly property int winW: 760
  readonly property int cmdW: 250
  property int bodyH: m.page === "" ? 380 : 470
  Behavior on bodyH { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

  // окно раскрывается по вертикали из середины (по очереди: i — номер окна)
  function grow(i) { return Math.max(0, Math.min(1, m.k * 3 - i * 0.6)) }

  Column {
    id: stack
    anchors.centerIn: parent
    spacing: 8

    // ── отряд ──
    QuestWin {
      id: party
      pal: qp
      width: m.winW; height: 76
      transform: Scale { origin.y: party.height / 2; yScale: m.grow(0) }
      opacity: m.grow(0) > 0 ? 1 : 0
      MouseArea { anchors.fill: parent }
      Row {
        anchors.verticalCenter: parent.verticalCenter
        x: 6
        spacing: 18
        Image { source: qp.sprite("hero"); smooth: false; width: 48; height: 48; anchors.verticalCenter: parent.verticalCenter }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 8
          Text { text: String(Quickshell.env("USER") || "hero").toUpperCase(); color: qp.text; font.family: qp.font(16); font.pixelSize: qp.size(16) }
          Text { text: "LV " + (Math.floor(m.uptime / 86400) + 1) + "   ВОИН ARCH"; color: qp.dim; font.family: qp.font(8); font.pixelSize: qp.size(8) }
        }
        Item { width: 40; height: 1 }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 8
          Repeater {
            model: [["HP", m.hp, qp.hp, Math.round(m.hp * 100) + "/100"], ["MP", 1 - m.mem, qp.mp, Math.round((1 - m.mem) * 100) + "/100"]]
            Row {
              id: bar
              required property var modelData
              spacing: 10
              Text { width: 28; text: bar.modelData[0]; color: qp.hi; font.family: qp.font(8); font.pixelSize: qp.size(8); anchors.verticalCenter: parent.verticalCenter }
              Rectangle {
                width: 200; height: 10
                anchors.verticalCenter: parent.verticalCenter
                color: qp.ink; border.width: 1; border.color: qp.frame2; antialiasing: false
                Rectangle { x: 2; y: 2; height: 6; width: (parent.width - 4) * Math.max(0, Math.min(1, bar.modelData[1])); color: bar.modelData[2]; antialiasing: false }
              }
              Text { text: bar.modelData[3]; color: qp.text; font.family: qp.mono; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
            }
          }
        }
      }
    }

    Row {
      spacing: 8
      // ── команды ──
      QuestWin {
        id: cmds
        pal: qp
        width: m.cmdW; height: m.bodyH
        transform: Scale { origin.y: cmds.height / 2; yScale: m.grow(1) }
        opacity: m.grow(1) > 0 ? 1 : 0
        MouseArea { anchors.fill: parent }
        Column {
          x: 26; y: 4
          spacing: 0
          Repeater {
            model: m.items
            Item {
              id: row
              required property var modelData
              required property int index
              readonly property bool isCur: index === m.sel
              width: m.cmdW - 40; height: 34
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData[1]
                color: row.isCur ? qp.hi : row.modelData[2] === "spell" ? qp.mp : qp.text
                opacity: m.page !== "" && !row.isCur ? 0.45 : 1
                font.family: qp.font(16); font.pixelSize: qp.size(16)
              }
              Text {   // переключатель заклинания: ● горит / ○ нет
                visible: row.modelData[2] === "spell"
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                text: m.on(row.modelData[0]) ? "●" : "○"
                color: m.on(row.modelData[0]) ? qp.hp : qp.dim
                font.family: qp.body; font.pixelSize: 16
              }
              MouseArea {
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onEntered: if (m.page === "") m.sel = row.index
                onClicked: { m.sel = row.index; m.act(row.modelData) }
              }
            }
          }
        }
        // рука-курсор у выбранной команды, покачивается
        Image {
          source: qp.sprite("hand")
          smooth: false
          width: 18; height: 12
          x: 2 + bob
          y: 4 + m.sel * 34 + 11
          property real bob: 0
          Behavior on y { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }
          SequentialAnimation on bob {
            running: m.open; loops: Animation.Infinite
            PauseAnimation { duration: 450 }
            NumberAnimation { to: 3; duration: 1 }
            PauseAnimation { duration: 450 }
            NumberAnimation { to: 0; duration: 1 }
          }
        }
      }

      // ── подробности / раздел ──
      QuestWin {
        id: info
        pal: qp
        width: m.winW - m.cmdW - 8; height: m.bodyH
        transform: Scale { origin.y: info.height / 2; yScale: m.grow(2) }
        opacity: m.grow(2) > 0 ? 1 : 0
        MouseArea { anchors.fill: parent }

        Column {
          visible: m.page === ""
          anchors.fill: parent
          anchors.margins: 6
          spacing: 18
          Row {
            spacing: 14
            Image {
              anchors.verticalCenter: parent.verticalCenter
              source: qp.sprite(m.cur[2] === "spell" ? "potion" : m.cur[0] === "power" ? "skull" : m.cur[0] === "tweak" ? "chest" : m.cur[0] === "shot" ? "star" : "sword")
              smooth: false; width: 36; height: 36; fillMode: Image.PreserveAspectFit
            }
            Text { anchors.verticalCenter: parent.verticalCenter; text: m.cur[1]; color: qp.hi; font.family: qp.font(16); font.pixelSize: qp.size(16) }
          }
          Text {
            width: parent.width
            text: m.about[m.cur[0]] || ""
            wrapMode: Text.WordWrap
            color: qp.text
            font.family: qp.body; font.pixelSize: 20
          }
          // состояние выбранной команды
          Column {
            spacing: 12
            width: parent.width
            Repeater {
              model: {
                var s = m.st, id = m.cur[0]
                if (!s) return []
                if (id === "wifi") return [["Wi-Fi", s.wifi ? (s.ssid || "включён") : "выключен"]]
                if (id === "bt") return [["Bluetooth", s.bt ? "включён" : "выключен"]]
                if (id === "audio") return [["Громкость", s.muted ? "тишина" : Math.round(s.vol * 100) + "%"], ["Микрофон", s.micMuted ? "заглушён" : Math.round(s.micVol * 100) + "%"]]
                if (m.cur[2] === "spell") return [["Состояние", m.on(id) ? "действует" : "не наложено"]]
                return []
              }
              Row {
                id: st
                required property var modelData
                spacing: 12
                Text { width: 170; text: st.modelData[0]; color: qp.dim; font.family: qp.body; font.pixelSize: 18 }
                Text { text: st.modelData[1]; color: qp.text; font.family: qp.body; font.pixelSize: 18 }
              }
            }
          }
          Text {
            text: m.cur[2] === "page" ? "▶ Enter — открыть" : m.cur[2] === "spell" ? "▶ Enter — сотворить" : "▶ Enter — выполнить"
            color: qp.dim
            font.family: qp.font(8); font.pixelSize: qp.size(8)
          }
        }

        SectionBody {
          id: sbody
          visible: m.page !== ""
          anchors.fill: parent
          anchors.margins: 4
          md: m.md; page: m.page
          ink: qp.text; dim: qp.dim; litFill: qp.hi; litInk: qp.ink; hoverFill: qp.alpha(qp.frame, 0.12); line: qp.frame2
          radius: 2; size: 16; rowH: 34; field: qp.alpha(qp.ink, 0.35); font: qp.body; bar: "blocks"
          textOn: "● "; textOff: "○ "
        }
      }
    }

    // ── подсказки ──
    QuestWin {
      id: help
      pal: qp
      width: m.winW; height: 40
      pad: 0
      transform: Scale { origin.y: help.height / 2; yScale: m.grow(3) }
      opacity: m.grow(3) > 0 ? 1 : 0
      MouseArea { anchors.fill: parent }
      Row {
        anchors.centerIn: parent
        spacing: 34
        Repeater {
          model: m.page === "" ? ["↑↓ ВЫБОР", "ENTER ДЕЙСТВИЕ", "ESC ЗАКРЫТЬ"] : ["↑↓ ВЫБОР", "ENTER ДЕЙСТВИЕ", "ESC НАЗАД"]
          Text { required property string modelData; text: modelData; color: qp.dim; font.family: qp.font(8); font.pixelSize: qp.size(8) }
        }
      }
    }
  }
}

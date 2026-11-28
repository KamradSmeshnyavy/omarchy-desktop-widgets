import QtQuick
import Quickshell
import ".."

// Меню Super+M райса Cozy Room — инвентарь (свой): деревянный шкаф (RoomWood) с сеткой 4 × 3 ячеек-углублений,
// в каждой — предмет комнаты пиксельным спрайтом ×6. Предмет показывает своё состояние сам: свеча — яркость (полоска
// в ячейке), рог — громкость, звезда горит — ночной свет, кот спит — не беспокоить, над кружкой пар — не засыпать,
// микрофон перечёркнут — заглушён, антенна и кристалл тускнеют, когда Wi-Fi / Bluetooth выключены.
// Справа — записка (RoomNote) про выбранный предмет: что это, что сейчас, что сделает Enter.
// Стрелки / hjkl — рамка по сетке, Enter — использовать (переключить, открыть, сделать), колесо над свечой / рогом —
// яркость / громкость. Антенна, рог и кристалл раскрываются запиской-разделом поверх (сети, устройства, звук), Esc — назад.
MenuBase {
  id: m
  body: sbody
  RoomPal { id: rp }
  // [id, имя, спрайт вкл, спрайт выкл, вид: page | toggle | level | act]
  readonly property var items: [
    ["wifi", "Антенна", "antenna", "antenna", "page"], ["audio", "Рог", "horn", "horn", "page"],
    ["bt", "Кристалл", "gem", "gem", "page"], ["bright", "Свеча", "candle", "candle-off", "level"],
    ["night", "Звезда", "star", "star-off", "toggle"], ["dnd", "Кот", "cat-sleep", "cat", "toggle"],
    ["awake", "Кружка", "mug", "mug-cold", "toggle"], ["mic", "Микрофон", "mic", "mic-off", "toggle"],
    ["radio", "Радио", "radio", "radio", "act"], ["shot", "Фотоаппарат", "camera", "camera", "act"],
    ["tweak", "Гаечный ключ", "wrench", "wrench", "act"], ["power", "Дверь", "door", "door", "act"]]
  readonly property var about: ({
    wifi: "Ловит сеть. Список сетей, пароль, DNS.", audio: "Громкость, выход звука и микрофон.",
    bt: "Зовёт наушники, мышь и прочие устройства.", bright: "Сколько света в комнате — яркость экрана.",
    night: "Тёплый свет для глаз — ночной режим.", dnd: "Пока кот спит, уведомления не будят.",
    awake: "Пока чай горячий, экран не гаснет и не засыпает.", mic: "Слышит ли комната ваш голос.",
    radio: "Плеер: что играет сейчас.", shot: "Снимок экрана.", tweak: "Customizer: облик, анимации, обои.",
    power: "Уйти: блокировка, сон, выключение." })
  property int sel: 0
  onOpenChanged: if (open && page === "") sel = 0
  onPageChanged: { var i = items.findIndex(function(d) { return d[0] === page }); if (i >= 0) sel = i }
  readonly property var cur: items[sel]

  function on(id) {
    var s = m.st
    if (!s) return true
    return id === "night" ? s.night : id === "dnd" ? s.dnd : id === "awake" ? s.caffeine : id === "mic" ? !s.micMuted
      : id === "wifi" ? s.wifi : id === "bt" ? s.bt : id === "audio" ? !s.muted : id === "bright" ? s.bright !== 0 : true
  }
  function level(id) {
    var s = m.st
    if (!s) return -1
    return id === "bright" ? s.bright : id === "audio" ? (s.muted ? 0 : s.vol) : -1
  }
  function stateOf(id) {
    var s = m.st
    if (!s) return ""
    if (id === "wifi") return s.wifi ? (s.ssid ? "поймала «" + s.ssid + "»" : "включена") : "молчит"
    if (id === "bt") return s.bt ? "светится" : "погас"
    if (id === "audio") return s.muted ? "тишина" : "громкость " + Math.round(s.vol * 100) + "%"
    if (id === "bright") return s.bright < 0 ? "свет как есть" : "свет " + Math.round(s.bright * 100) + "%"
    if (id === "night") return s.night ? "горит" : "не горит"
    if (id === "dnd") return s.dnd ? "спит — тихо" : "не спит"
    if (id === "awake") return s.caffeine ? "чай горячий" : "чай остыл"
    if (id === "mic") return s.micMuted ? "заглушён" : "слушает"
    return ""
  }
  function use(d) {
    var s = m.st
    if (d[4] === "page") { page = d[0]; return }
    if (d[0] === "bright") { if (s) s.setBright(s.bright < 0 || s.bright >= 0.95 ? 0.25 : Math.min(1, s.bright + 0.25)); return }
    if (d[0] === "night") s.toggleNight(); else if (d[0] === "dnd") s.toggleDnd(); else if (d[0] === "awake") s.toggleCaffeine()
    else if (d[0] === "mic") s.toggleMic()
    else if (d[0] === "radio") { m.close(); m.host.playerOpen = !m.host.playerOpen }
    else if (d[0] === "shot") { m.close(); m.run(["omarchy-capture-screenshot"]) }
    else if (d[0] === "tweak") { m.close(); m.run(["omarchy-shell", "shell", "toggle", "kamradsmeshnyavy.customizer"]) }
    else if (d[0] === "power") { m.close(); m.host.powerOpen = true }
  }
  function wheel(id, up) {
    var s = m.st
    if (!s) return
    if (id === "bright") s.setBright(Math.max(0.02, Math.min(1, (s.bright < 0 ? 0.5 : s.bright) + (up ? 0.05 : -0.05))))
    else if (id === "audio") s.setVol(Math.max(0, Math.min(1.5, s.vol + (up ? 0.05 : -0.05))))
  }
  function keys(e) {
    if (m.page !== "") return false
    var n = items.length
    if (e.key === Qt.Key_Right || e.text === "l") { sel = (sel + 1) % n; return true }
    if (e.key === Qt.Key_Left || e.text === "h") { sel = (sel + n - 1) % n; return true }
    if (e.key === Qt.Key_Down || e.text === "j") { sel = (sel + 4) % n; return true }
    if (e.key === Qt.Key_Up || e.text === "k") { sel = (sel + n - 4) % n; return true }
    if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) { use(items[sel]); return true }
    return false
  }

  readonly property int cell: 104
  Row {
    anchors.centerIn: parent
    spacing: 26
    opacity: Math.min(1, m.k * 1.6)
    transform: Translate { y: (1 - m.k) * 40 }

    // ── шкаф ──
    RoomWood {
      id: chest
      pal: rp
      width: 4 * m.cell + 3 * 10 + 44; height: 3 * m.cell + 2 * 10 + 82
      pad: 0
      MouseArea { anchors.fill: parent }
      Text { x: 22; y: 12; text: "ИНВЕНТАРЬ"; color: rp.onWood; font.family: rp.font; font.pixelSize: 20; font.bold: true }
      Text { anchors.right: parent.right; anchors.rightMargin: 22; y: 15; text: (m.sel + 1) + " / " + m.items.length; color: rp.onWoodDim; font.family: rp.mono; font.pixelSize: 14 }
      Grid {
        x: 19; y: 50
        columns: 4
        spacing: 10
        Repeater {
          model: m.items
          Item {
            id: slot
            required property var modelData
            required property int index
            readonly property bool isSel: index === m.sel
            readonly property bool lit: m.on(modelData[0])
            readonly property real lvl: m.level(modelData[0])
            width: m.cell; height: m.cell
            Rectangle {
              anchors.fill: parent
              color: slot.isSel ? rp.mix(rp.ink, rp.lamp, 0.16) : rp.alpha(rp.ink, 0.55)
              border.width: slot.isSel ? 3 : 2
              border.color: slot.isSel ? rp.lamp : rp.dark
              radius: 3
              antialiasing: false
            }
            Image {
              id: ic
              anchors.centerIn: parent
              anchors.verticalCenterOffset: -6
              source: rp.sprite(slot.lit ? slot.modelData[2] : slot.modelData[3])
              smooth: false
              width: sourceSize.width * 6; height: sourceSize.height * 6
              opacity: slot.lit || slot.modelData[2] !== slot.modelData[3] ? 1 : 0.35
              scale: slot.isSel ? 1.08 : 1
              Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
            }
            // уровень (свеча — яркость, рог — громкость): полоска клетками внизу ячейки
            Row {
              visible: slot.lvl >= 0
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.bottom: parent.bottom; anchors.bottomMargin: 8
              spacing: 2
              Repeater {
                model: 8
                Rectangle { required property int index; width: 8; height: 5; antialiasing: false; color: index < Math.round(Math.min(1, slot.lvl) * 8) ? rp.lamp : rp.alpha(rp.text, 0.15) }
              }
            }
            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: if (m.page === "") m.sel = slot.index
              onClicked: { m.sel = slot.index; m.use(slot.modelData) }
              onWheel: function(w) { m.wheel(slot.modelData[0], w.angleDelta.y > 0) }
            }
          }
        }
      }
    }

    // ── записка про предмет / раздел ──
    RoomNote {
      id: note
      pal: rp
      tilt: m.page === "" ? 2 : 0
      Behavior on tilt { NumberAnimation { duration: 160 } }
      width: m.page === "" ? 330 : 520
      height: chest.height
      Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
      MouseArea { anchors.fill: parent }

      Column {
        visible: m.page === ""
        anchors.fill: parent
        spacing: 14
        Row {
          spacing: 14
          Image { source: rp.sprite(m.on(m.cur[0]) ? m.cur[2] : m.cur[3]); smooth: false; width: sourceSize.width * 5; height: sourceSize.height * 5; anchors.verticalCenter: parent.verticalCenter }
          Text { text: m.cur[1]; color: rp.paperink; font.family: rp.font; font.pixelSize: 26; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
        }
        Rectangle { width: parent.width; height: 1; color: rp.alpha(rp.paperink, 0.25) }
        Text { width: parent.width; wrapMode: Text.WordWrap; text: m.about[m.cur[0]] || ""; color: rp.paperink; font.family: rp.font; font.pixelSize: 19 }
        Text {
          visible: text !== ""
          width: parent.width; wrapMode: Text.WordWrap
          text: m.stateOf(m.cur[0])
          color: rp.mix(rp.paperink, rp.red, 0.45)
          font.family: rp.font; font.pixelSize: 19; font.italic: true
        }
        Item { width: 1; height: 10 }
        Text {
          width: parent.width; wrapMode: Text.WordWrap
          text: m.cur[4] === "page" ? "Enter — открыть" : m.cur[4] === "toggle" ? "Enter — переключить" : m.cur[4] === "level" ? "Enter — ярче · колесо — точнее" : "Enter — сделать"
          color: rp.alpha(rp.paperink, 0.6)
          font.family: rp.font; font.pixelSize: 16
        }
        Text {
          width: parent.width; wrapMode: Text.WordWrap
          text: "стрелки — другой предмет · Esc — закрыть"
          color: rp.alpha(rp.paperink, 0.45)
          font.family: rp.font; font.pixelSize: 14
        }
      }

      Column {
        visible: m.page !== ""
        anchors.fill: parent
        spacing: 8
        Text { text: m.cur[1] + " · " + m.stateOf(m.cur[0]); color: rp.paperink; font.family: rp.font; font.pixelSize: 20; font.bold: true }
        SectionBody {
          id: sbody
          width: parent.width; height: parent.height - 36
          md: m.md; page: m.page
          ink: rp.paperink; dim: rp.alpha(rp.paperink, 0.6); litFill: rp.lamp; litInk: rp.ink; hoverFill: rp.alpha(rp.lamp, 0.2)
          line: rp.alpha(rp.paperink, 0.3); radius: 3; size: 17; rowH: 34; field: rp.alpha(rp.paperink, 0.07); font: rp.font; bar: "blocks"
          textOn: "● "; textOff: "○ "
        }
      }
    }
  }
}

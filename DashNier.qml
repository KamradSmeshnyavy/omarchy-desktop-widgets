import QtQuick
import Quickshell
import Quickshell.Io

// Дашборд Unit-3 — в духе меню паузы NieR:Automata (свой, по облику Unit-3, samyns, MIT: бежевые листы #d6cfb5 с рамкой
// чернилами #463f2e и сеткой, красный #6e2a2a, Share Tech Mono). 860 × 500: шапка «SYSTEM — システム» с вкладками-
// разделами и временем; слева — карточка юнита (ромб NR / 2B, user@host, время работы) и «PLUG-IN CHIPS» — CPU / MEM /
// DISK / TEMP сегментными шкалами; по центру — крупное время, дата, японский день недели, погода и «INTEL» — ближайшие
// напоминания; справа — «MEDIA» (обложка со строками развёртки, трек, ◀ ▶ ▶▶) и «LOG» — последние уведомления. По
// листам бежит красная строка развёртки, вкладки сверху ведут: STATUS — Super+M, MEDIA — плеер, LOG — история.
Item {
  id: n
  required property var host
  property real rise: 1
  readonly property bool live: rise > 0.01
  width: 860
  height: 500

  readonly property color paper: "#d6cfb5"
  readonly property color ink: "#463f2e"
  readonly property color strong: "#2e2a1f"
  readonly property color soft: "#7a7358"
  readonly property color red: "#6e2a2a"
  function inkA(a) { return Qt.rgba(70 / 255, 63 / 255, 46 / 255, a) }
  readonly property string f: Qt.fontFamilies().indexOf("Share Tech Mono") !== -1 ? "Share Tech Mono" : "monospace"

  SurfState { id: st; live: n.live }

  // CPU / MEM / DISK / TEMP
  property real cpu: 0
  property real mem: 0
  property real disk: 0
  property real temp: 0
  property var prev: null
  Process {
    id: probe
    command: ["bash", "-c", "read -r _ u ni s i w q sq stl _ < /proc/stat; echo cpu $((u+ni+s+i+w+q+sq+stl)) $((i+w));" +
      "awk '/^MemTotal|^MemAvailable/{printf \"%s \", $2} END{print \"\"}' /proc/meminfo | sed 's/^/mem /';" +
      "df -P / | awk 'NR==2{print \"disk\", $5}';" +
      "t=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1); echo temp ${t:-0}"]
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
          var x = lines[i].trim().split(/\s+/)
          if (x[0] === "cpu") {
            var tot = Number(x[1]), idle = Number(x[2])
            if (n.prev && tot > n.prev.total) n.cpu = Math.max(0, Math.min(1, 1 - (idle - n.prev.idle) / (tot - n.prev.total)))
            n.prev = { total: tot, idle: idle }
          } else if (x[0] === "mem" && Number(x[1]) > 0) n.mem = 1 - Number(x[2]) / Number(x[1])
          else if (x[0] === "disk") n.disk = parseInt(x[1]) / 100
          else if (x[0] === "temp") n.temp = Math.min(1, Number(x[1]) / 1000 / 100)
        }
      }
    }
  }
  Timer { interval: 2000; repeat: true; running: n.live; triggeredOnStart: true; onTriggered: if (!probe.running) probe.running = true }

  property date now: new Date()
  Timer { interval: 1000; repeat: true; running: n.live; triggeredOnStart: true; onTriggered: n.now = new Date() }
  readonly property string host_: Quickshell.env("HOSTNAME") || ""

  component Sheet: Rectangle {
    color: n.paper
    border.color: n.ink; border.width: 1
    clip: true
    Repeater { model: Math.ceil(parent.width / 20); Rectangle { x: index * 20; width: 1; height: parent.height; color: n.inkA(0.06) } }
    Repeater { model: Math.ceil(parent.height / 20); Rectangle { y: index * 20; width: parent.width; height: 1; color: n.inkA(0.06) } }
  }
  component Head: Item {
    property string en: ""
    property string jp: ""
    width: parent ? parent.width : 0; height: 26
    Row {
      x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 10
      Rectangle { width: 6; height: 6; color: n.ink; rotation: 45; anchors.verticalCenter: parent.verticalCenter }
      Text { text: parent.parent.en; font.family: n.f; font.pixelSize: 10; font.letterSpacing: 3; color: n.strong }
      Text { text: parent.parent.jp; font.pixelSize: 8; color: n.soft; anchors.verticalCenter: parent.verticalCenter }
    }
    Rectangle { anchors.bottom: parent.bottom; x: 8; width: parent.width - 16; height: 1; color: n.inkA(0.25) }
  }
  component Txt: Text { font.family: n.f; color: n.ink }

  opacity: rise
  transform: Translate { y: (1 - n.rise) * -14 }

  // ── шапка ──
  Sheet {
    id: top
    width: parent.width; height: 44
    Row {
      x: 18; anchors.verticalCenter: parent.verticalCenter; spacing: 14
      Txt { text: "SYSTEM"; font.pixelSize: 11; font.letterSpacing: 3.5; color: n.strong }
      Rectangle { width: 24; height: 1; color: n.soft; anchors.verticalCenter: parent.verticalCenter }
      Text { text: "システム"; font.pixelSize: 10; color: n.soft; anchors.verticalCenter: parent.verticalCenter }
    }
    Row {
      anchors.centerIn: parent; spacing: 6
      Repeater {
        model: [["STATUS", "settings"], ["MEDIA", "player"], ["LOG", "log"], ["POWER", "power"]]
        Rectangle {
          required property var modelData
          required property int index
          width: 86; height: 24
          color: index === 0 || tabH.hovered ? n.ink : "transparent"
          border.color: n.ink; border.width: 1
          Txt { anchors.centerIn: parent; text: modelData[0]; font.pixelSize: 9; font.letterSpacing: 2.5; color: index === 0 || tabH.hovered ? n.paper : n.ink }
          HoverHandler { id: tabH; cursorShape: Qt.PointingHandCursor }
          TapHandler {
            onTapped: {
              n.host.dashboardOpen = false
              var k = modelData[1]
              if (k === "settings") n.host.settingsOpen = true
              else if (k === "player") n.host.playerOpen = true
              else if (k === "power") n.host.powerOpen = true
              else Quickshell.execDetached(["omarchy-shell", "notifications", "showHistory"])
            }
          }
        }
      }
    }
    Txt { anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter } text: Qt.formatTime(n.now, "HH:mm:ss") + "  ·  SESSION 0471"; font.pixelSize: 9; font.letterSpacing: 2; color: n.soft }
  }

  // ── слева: юнит и чипы ──
  Column {
    y: top.height + 12; width: 260; spacing: 12
    Sheet {
      width: parent.width; height: 150
      Head { en: "UNIT"; jp: "ユニット" }
      Row {
        x: 16; y: 40; spacing: 16
        Rectangle {
          width: 72; height: 72; color: "transparent"; border.color: n.ink; border.width: 1
          Rectangle { width: 48; height: 48; color: n.ink; anchors.centerIn: parent; rotation: 45 }
          Txt { text: "NR"; font.pixelSize: 7; color: n.soft; opacity: 0.6; anchors { top: parent.top; left: parent.left; margins: 3 } }
          Txt { text: "2B"; font.pixelSize: 7; color: n.soft; opacity: 0.6; anchors { bottom: parent.bottom; right: parent.right; margins: 3 } }
        }
        Column {
          spacing: 5; anchors.verticalCenter: parent.verticalCenter
          Txt { width: 140; elide: Text.ElideRight; text: (Quickshell.env("USER") || "unit").toUpperCase(); font.pixelSize: 13; font.letterSpacing: 3; color: n.strong }
          Text { text: "ユニット · アクティブ"; font.pixelSize: 8; color: n.soft }
          Txt { text: "UPTIME · " + String(st.uptime || "—").toUpperCase(); font.pixelSize: 8; font.letterSpacing: 1.5; color: n.soft; width: 140; elide: Text.ElideRight }
          Txt { text: "NET · " + (st.ssid !== "" ? st.ssid : "--"); font.pixelSize: 8; font.letterSpacing: 1.5; color: n.soft; width: 140; elide: Text.ElideRight }
        }
      }
    }
    Sheet {
      width: parent.width; height: 270
      Head { en: "PLUG-IN CHIPS"; jp: "プラグインチップ" }
      Column {
        x: 16; y: 40; width: parent.width - 32; spacing: 14
        Repeater {
          model: [["CPU", n.cpu, "演算"], ["MEM", n.mem, "記憶"], ["DISK", n.disk, "保存"], ["TEMP", n.temp, "温度"]]
          Column {
            required property var modelData
            width: parent.width; spacing: 5
            Row {
              width: parent.width
              Txt { text: modelData[0]; font.pixelSize: 10; font.letterSpacing: 2.5; width: 60 }
              Text { text: modelData[2]; font.pixelSize: 8; color: n.soft; width: parent.width - 60 - 40 }
              Txt { text: Math.round(modelData[1] * 100) + "%"; font.pixelSize: 10; width: 40; horizontalAlignment: Text.AlignRight; color: modelData[1] > 0.85 ? n.red : n.ink }
            }
            Row {
              spacing: 2
              Repeater {
                model: 24
                Rectangle {
                  required property int index
                  readonly property bool on: index < Math.round(modelData[1] * 24)
                  width: (228 - 23 * 2) / 24; height: on ? 9 : 5
                  anchors.bottom: parent ? parent.bottom : undefined
                  color: on ? (modelData[1] > 0.85 ? n.red : n.ink) : n.inkA(0.18)
                  Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                }
              }
            }
          }
        }
      }
    }
  }

  // ── центр: время, погода, напоминания ──
  Column {
    x: 272; y: top.height + 12; width: 304; spacing: 12
    Sheet {
      width: parent.width; height: 220
      Head { en: "TIME"; jp: "時刻" }
      Column {
        anchors.horizontalCenter: parent.horizontalCenter; y: 44; spacing: 6
        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(n.now, "HH:mm"); font.pixelSize: 64; font.letterSpacing: 4; color: n.strong }
        Txt { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(n.now, "yyyy.MM.dd").toUpperCase(); font.pixelSize: 11; font.letterSpacing: 4; color: n.soft }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: ["日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日"][n.now.getDay()]; font.pixelSize: 10; color: n.soft }
        Item { width: 1; height: 6 }
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 240; height: 1; color: n.inkA(0.25) }
        Txt {
          anchors.horizontalCenter: parent.horizontalCenter
          readonly property var w: n.host.weather
          text: w && w.temp !== undefined ? "WEATHER · " + String(w.city || "").toUpperCase() + " · " + Math.round(w.temp) + "°" : "WEATHER · NO DATA"
          font.pixelSize: 9; font.letterSpacing: 2.5
        }
      }
    }
    Sheet {
      width: parent.width; height: 200
      Head { en: "INTEL"; jp: "情報" }
      Column {
        x: 16; y: 40; width: parent.width - 32; spacing: 8
        Repeater {
          model: st.reminders.slice(0, 5)
          Row {
            required property var modelData
            spacing: 8
            Txt { text: "▸"; color: n.red; font.pixelSize: 10 }
            Txt { width: 250; elide: Text.ElideRight; text: String(modelData.message || modelData.text || modelData.title || "").toUpperCase() + (modelData.when ? " · " + modelData.when : ""); font.pixelSize: 9; font.letterSpacing: 1.5 }
          }
        }
        Txt { visible: st.reminders.length === 0; text: "▸ NO PENDING ORDERS"; font.pixelSize: 9; font.letterSpacing: 2.5; color: n.soft }
      }
    }
  }

  // ── справа: медиа и журнал ──
  Column {
    x: 588; y: top.height + 12; width: 272; spacing: 12
    Sheet {
      id: media
      width: parent.width; height: 176
      readonly property var p: n.host.player
      Head { en: "MEDIA"; jp: "音楽" }
      Rectangle {
        x: 14; y: 40; width: 86; height: 86; color: n.ink; clip: true
        Image { anchors.fill: parent; source: media.p ? String(media.p.trackArtUrl || "") : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; opacity: 0.9 }
        Repeater { model: 43; Rectangle { y: index * 2; width: 86; height: 1; color: Qt.rgba(0, 0, 0, 0.18) } }
      }
      Column {
        x: 112; y: 42; width: parent.width - 126; spacing: 4
        Txt { width: parent.width; elide: Text.ElideRight; text: media.p && media.p.trackTitle ? media.p.trackTitle.toUpperCase() : "NO SIGNAL"; font.pixelSize: 11; font.letterSpacing: 1.5; color: n.strong }
        Txt { width: parent.width; elide: Text.ElideRight; text: media.p && media.p.trackArtist ? media.p.trackArtist : "— // —"; font.pixelSize: 9; font.letterSpacing: 1.5; color: n.soft }
      }
      Row {
        x: 112; y: 98; spacing: 6
        Repeater {
          model: [["◀", "previous", 26], [media.p && media.p.isPlaying ? "PAUSE" : "PLAY", "togglePlaying", 60], ["▶", "next", 26]]
          Rectangle {
            required property var modelData
            width: modelData[2]; height: 24; color: bh.hovered ? n.ink : "transparent"; border.color: n.ink; border.width: 1
            Txt { anchors.centerIn: parent; text: modelData[0]; font.pixelSize: 9; font.letterSpacing: 2; color: bh.hovered ? n.paper : n.ink }
            HoverHandler { id: bh; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: if (media.p) media.p[modelData[1]]() }
          }
        }
      }
      Rectangle {
        x: 14; y: 142; width: parent.width - 28; height: 2; color: n.inkA(0.2)
        Rectangle { height: 2; color: n.red; width: media.p && media.p.length > 0 ? parent.width * Math.min(1, media.p.position / media.p.length) : 0 }
      }
    }
    Sheet {
      width: parent.width; height: 244
      Head { en: "LOG"; jp: "記録" }
      Column {
        x: 12; y: 36; width: parent.width - 24; spacing: 4
        Repeater {
          model: st.notes.slice(0, 5)
          Rectangle {
            required property var modelData
            width: parent.width; height: 36; color: "transparent"; border.color: n.inkA(0.35); border.width: 1
            Rectangle { width: 3; height: parent.height; color: Number(modelData.urgency) === 2 ? n.red : n.ink }
            Column {
              x: 10; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 18; spacing: 2
              Txt { width: parent.width; elide: Text.ElideRight; text: String(modelData.app || "SYSTEM").toUpperCase() + "  ·  " + Qt.formatTime(new Date(Number(modelData.timestamp || 0)), "HH:mm"); font.pixelSize: 7; font.letterSpacing: 1.5; color: n.soft }
              Txt { width: parent.width; elide: Text.ElideRight; text: String(modelData.summary || ""); font.pixelSize: 10; color: n.strong }
            }
          }
        }
        Txt { visible: st.notes.length === 0; text: "▸ LOG EMPTY"; font.pixelSize: 9; font.letterSpacing: 2.5; color: n.soft }
      }
    }
  }

  // красная строка развёртки по всему дашборду
  Rectangle {
    width: parent.width; height: 1; z: 30
    gradient: Gradient { orientation: Gradient.Horizontal
      GradientStop { position: 0; color: "transparent" }
      GradientStop { position: 0.5; color: n.red }
      GradientStop { position: 1; color: "transparent" } }
    SequentialAnimation on y {
      running: n.live; loops: Animation.Infinite
      NumberAnimation { from: 0; to: n.height; duration: 4200 }
      PauseAnimation { duration: 900 }
    }
  }
}

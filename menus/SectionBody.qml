import QtQuick

// Содержимое раздела меню Super+M (wifi / bt / audio) с обликом, заданным снаружи. Строка — шрифт font, высота rowH,
// скругление radius; выбранная / включённая — заливка litFill и текст litInk; наведённая — hoverFill; рамка — line;
// rowBorder — толщина постоянной рамки строки (0 — только при наведении). textOn / textOff (например «[x] » / «[ ] »)
// ставятся перед строками-переключателями; bar — вид ползунка: "fill" или "blocks" (█▒ для терминала).
//
// Wi-Fi: сохранённая сеть подключается без пароля, новая — пароль в поле прямо под строкой; «›» у сохранённой —
// карточка сети: адрес, шлюз, DNS (пресеты и свои адреса), автоподключение, новый пароль, показать пароль, забыть.
// Ниже — сохранённые сети вне зоны, скрытая сеть, пересканировать. Bluetooth: «›» — подключить, доверять, забыть.
// Звук: громкость, микрофон и его громкость, выходы и входы. Клавиатура — через KeyNav (список прокручивается сам);
// back() — шаг назад внутри раздела (MenuShell зовёт его по Esc через body меню).
Flickable {
  id: sb
  property var md: null
  property string page: ""
  property color ink: "white"
  property color dim: Qt.rgba(ink.r, ink.g, ink.b, 0.6)
  property color litFill: "white"
  property color litInk: "black"
  property color hoverFill: Qt.rgba(ink.r, ink.g, ink.b, 0.08)
  property color line: Qt.rgba(ink.r, ink.g, ink.b, 0.25)
  property color field: "transparent"
  property string font: "monospace"
  property int size: 12
  property int rowH: 38
  property real radius: 8
  property int rowBorder: 0
  property string textOn: ""
  property string textOff: ""
  property string bar: "fill"
  readonly property var st: md ? md.st : null

  // состояние внутри раздела
  property string ask: ""          // ssid, для которого открыто поле пароля
  property string detail: ""       // uuid открытой карточки сети
  property string detailSsid: ""
  property string btDetail: ""     // mac открытой карточки устройства
  property bool hiddenForm: false
  property string hiddenSsid: ""
  property string confirm: ""      // действие, ждущее второго нажатия («forget»)
  readonly property var info: md ? md.info : ({})
  readonly property bool detailActive: info["GENERAL.STATE"] === "activated"
  readonly property var dev: {
    if (!md || btDetail === "") return null
    for (var i = 0; i < md.devices.length; i++) if (md.devices[i].mac === btDetail) return md.devices[i]
    return null
  }

  Binding { when: !!sb.md; target: sb.md; property: "hold"; value: sb.visible && (sb.ask !== "" || sb.hiddenForm) }

  function reset() { ask = ""; hiddenForm = false; hiddenSsid = ""; confirm = ""; btDetail = ""; closeDetail(); contentY = 0 }
  onPageChanged: reset()
  onVisibleChanged: if (!visible) reset()
  function openDetail(uuid, ssid) { ask = ""; confirm = ""; detail = uuid; detailSsid = ssid; if (md) md.details(uuid); contentY = 0 }
  function closeDetail() { detail = ""; detailSsid = ""; confirm = ""; if (md) md.closeDetails() }
  function back() {
    if (ask !== "") { ask = ""; return true }
    if (hiddenForm) { hiddenForm = false; hiddenSsid = ""; return true }
    if (detail !== "") { closeDetail(); contentY = 0; return true }
    if (btDetail !== "") { btDetail = ""; confirm = ""; contentY = 0; return true }
    return false
  }
  function tapNet(n) {
    if (n.active) openDetail(n.uuid, n.ssid)
    else if (n.saved || !n.secure) md.connectWifi(n.ssid, "")
    else ask = ask === n.ssid ? "" : n.ssid
  }
  function bars(sig) { return "▂▄▆█".slice(0, Math.max(1, Math.ceil(sig / 25))) }
  function list(v) { return v === undefined ? [] : Array.isArray(v) ? v : [v] }

  clip: true
  contentHeight: col.implicitHeight
  boundsBehavior: Flickable.StopAtBounds

  component Line: Item {
    id: ln
    property string text: ""
    property string tail: ""
    property bool on: false
    property bool toggle: false
    property bool more: false      // «›» справа — отдельная цель (мышь и клавиатура)
    property bool danger: false
    signal hit()
    signal moreHit()
    width: sb.width - 4; height: sb.rowH
    Rectangle {
      anchors.fill: parent; radius: sb.radius
      color: ln.on ? sb.litFill : lh.hovered ? sb.hoverFill : "transparent"
      border.width: ln.on ? sb.rowBorder : lh.hovered ? Math.max(1, sb.rowBorder) : sb.rowBorder; border.color: ln.on && sb.rowBorder === 0 ? sb.litFill : sb.line
    }
    Text {
      x: 12; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 24 - tl.implicitWidth - (ln.more ? sb.rowH : 0) - 12
      elide: Text.ElideRight; text: (ln.toggle ? (ln.on ? sb.textOn : sb.textOff) : "") + ln.text
      color: ln.on ? sb.litInk : sb.ink; opacity: ln.danger && !ln.on ? 0.85 : 1; font.family: sb.font; font.pixelSize: sb.size; font.underline: ln.danger
    }
    Text { id: tl; anchors.right: parent.right; anchors.rightMargin: ln.more ? sb.rowH + 4 : 12; anchors.verticalCenter: parent.verticalCenter; text: ln.tail; color: ln.on ? sb.litInk : sb.dim; font.family: sb.font; font.pixelSize: sb.size - 1 }
    HoverHandler { id: lh; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: ln.hit() }
    Item {
      visible: ln.more
      anchors.right: parent.right; width: sb.rowH; height: parent.height
      property real radius: sb.radius
      Rectangle { anchors.fill: parent; anchors.margins: 4; radius: Math.max(0, sb.radius - 2); color: mh.hovered ? (ln.on ? sb.litInk : sb.hoverFill) : "transparent"; opacity: ln.on && mh.hovered ? 0.2 : 1 }
      Text { anchors.centerIn: parent; text: "›"; color: ln.on ? sb.litInk : sb.ink; font.family: sb.font; font.pixelSize: sb.size + 6 }
      HoverHandler { id: mh; cursorShape: Qt.PointingHandCursor }
      TapHandler { onTapped: ln.moreHit() }
    }
  }
  // строка «ключ — значение», не нажимается
  component Kv: Item {
    property string k: ""
    property string v: ""
    width: sb.width - 4; height: Math.max(sb.rowH - 12, vt.implicitHeight + 6)
    Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: parent.k; color: sb.dim; font.family: sb.font; font.pixelSize: sb.size - 1 }
    Text { id: vt; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; width: Math.min(implicitWidth, parent.width * 0.68); horizontalAlignment: Text.AlignRight; wrapMode: Text.WrapAnywhere; text: parent.v || "—"; color: sb.ink; font.family: sb.font; font.pixelSize: sb.size - 1 }
  }
  component Head: Text {
    x: 4; topPadding: 6; color: sb.dim; font.family: sb.font; font.pixelSize: sb.size - 1
  }
  // поле ввода: Enter — accepted(text), Esc — cancelled; с клавиатуры — Enter на поле ставит в него курсор
  component Field: Item {
    id: fd
    property string placeholder: ""
    property bool password: false
    property bool autoFocus: false
    property alias text: ti.text
    signal accepted(string text)
    signal cancelled()
    property bool kbdNav: visible
    property real kbdRadius: sb.radius
    function kbdPress() { ti.forceActiveFocus() }
    width: sb.width - 4; height: sb.rowH
    Rectangle { anchors.fill: parent; radius: sb.radius; color: sb.field; border.width: ti.activeFocus ? Math.max(1, sb.rowBorder) + 1 : Math.max(1, sb.rowBorder); border.color: ti.activeFocus ? sb.ink : sb.line }
    TextInput {
      id: ti
      x: 12; width: parent.width - 24; anchors.verticalCenter: parent.verticalCenter; clip: true
      echoMode: fd.password ? TextInput.Password : TextInput.Normal; color: sb.ink; selectionColor: sb.litFill; selectedTextColor: sb.litInk
      font.family: sb.font; font.pixelSize: sb.size
      onVisibleChanged: if (visible && fd.autoFocus) forceActiveFocus()
      Component.onCompleted: if (visible && fd.autoFocus) forceActiveFocus()
      Keys.onReturnPressed: { var t = text; sb.forceActiveFocus(); fd.accepted(t) }
      Keys.onEnterPressed: { var t = text; sb.forceActiveFocus(); fd.accepted(t) }
      Keys.onEscapePressed: { text = ""; sb.forceActiveFocus(); fd.cancelled() }
      // ↑ / ↓ / Tab — уйти из поля, клавиша идёт дальше к KeyNav
      Keys.onPressed: function(e) { if (e.key === Qt.Key_Up || e.key === Qt.Key_Down || e.key === Qt.Key_Tab || e.key === Qt.Key_Backtab) { sb.forceActiveFocus(); e.accepted = false } }
      Text { visible: !parent.text.length; text: fd.placeholder; color: sb.dim; font: parent.font }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: ti.forceActiveFocus(); property bool kbdNav: false }
  }
  // ползунок 0…1: ←/→ с клавиатуры, Enter — mute / 50 %
  component Slider: Item {
    id: sl
    property string label: ""
    property real value: 0
    signal moved(real v)
    property bool kbdNav: visible
    property real kbdRadius: sb.radius
    function kbdPress() { sl.moved(sl.value > 0 ? 0 : 0.5) }
    function kbdAdjust(d) { sl.moved(Math.max(0, Math.min(1, sl.value + d * 0.05))) }
    width: sb.width - 4; height: sb.rowH + 22
    Text { x: 4; text: sl.label + " " + Math.round(sl.value * 100) + "%"; color: sb.ink; font.family: sb.font; font.pixelSize: sb.size }
    Rectangle {
      visible: sb.bar === "fill"
      y: 22; width: parent.width; height: sb.rowH - 14; radius: sb.radius; color: sb.field; border.width: Math.max(1, sb.rowBorder); border.color: sb.line
      Rectangle { x: 3; y: 3; height: parent.height - 6; radius: Math.max(0, sb.radius - 3); width: Math.max(0, (parent.width - 6) * Math.min(1, sl.value)); color: sb.litFill }
    }
    Text {
      visible: sb.bar === "blocks"
      y: 22; x: 4
      readonly property int n: 32
      readonly property int lit: Math.round(Math.min(1, sl.value) * n)
      text: "[" + "█".repeat(lit) + "▒".repeat(n - lit) + "]"
      color: sb.litFill; font.family: sb.font; font.pixelSize: sb.size
    }
    MouseArea { y: 22; width: parent.width; height: sb.rowH - 14; property bool kbdNav: false
      onPressed: function(e) { sl.moved(Math.max(0, Math.min(1, e.x / width))) }
      onPositionChanged: function(e) { if (pressed) sl.moved(Math.max(0, Math.min(1, e.x / width))) } }
  }

  Column {
    id: col
    width: sb.width
    spacing: 4

    // ── Wi-Fi: список ──
    readonly property bool wl: sb.page === "wifi" && sb.detail === ""
    Line { visible: col.wl; toggle: true; text: "wi-fi"; on: !!sb.st && sb.st.wifi; tail: sb.st && sb.st.wifi ? (sb.st.ssid || "on") : "off"; onHit: sb.st.toggleWifi() }
    Text {
      visible: sb.page === "wifi" && !!sb.md && sb.md.wifiMsg !== ""
      x: 12; width: sb.width - 28; wrapMode: Text.Wrap
      text: sb.md ? sb.md.wifiMsg : ""; color: sb.ink; opacity: 0.8; font.family: sb.font; font.pixelSize: sb.size - 1
    }
    Repeater {
      model: col.wl && !sb.hiddenForm && sb.md ? sb.md.networks : []
      Column {
        id: nd
        required property var modelData
        spacing: 4
        Line {
          text: (nd.modelData.secure ? "🔒 " : "   ") + nd.modelData.ssid
          tail: nd.modelData.active ? "connected" : (nd.modelData.saved ? "saved  " : "") + sb.bars(nd.modelData.signal)
          on: nd.modelData.active
          more: nd.modelData.saved
          onHit: sb.tapNet(nd.modelData)
          onMoreHit: sb.openDetail(nd.modelData.uuid, nd.modelData.ssid)
        }
        Field {
          visible: sb.ask === nd.modelData.ssid
          autoFocus: true; password: true
          placeholder: "password for " + nd.modelData.ssid + "  (enter — connect, esc — cancel)"
          onAccepted: function(t) { if (t.length) sb.md.connectWifi(nd.modelData.ssid, t); sb.ask = ""; text = "" }
          onCancelled: sb.ask = ""
        }
      }
    }
    // сохранённые вне зоны
    Head { visible: col.wl && !sb.hiddenForm && outRep.count > 0; text: "saved · out of range" }
    Repeater {
      id: outRep
      model: {
        if (!col.wl || sb.hiddenForm || !sb.md) return []
        var near = ({})
        for (var i = 0; i < sb.md.networks.length; i++) near[sb.md.networks[i].ssid] = true
        return sb.md.savedList.filter(function(s) { return !near[s.ssid] })
      }
      Line {
        required property var modelData
        text: "   " + modelData.ssid; tail: "saved"; more: true
        onHit: sb.openDetail(modelData.uuid, modelData.ssid)
        onMoreHit: sb.openDetail(modelData.uuid, modelData.ssid)
      }
    }
    // скрытая сеть
    Line { visible: col.wl; text: sb.hiddenForm ? "‹ hidden network" : "+ hidden network"; on: sb.hiddenForm; onHit: { sb.hiddenForm = !sb.hiddenForm; sb.hiddenSsid = "" } }
    Field {
      visible: col.wl && sb.hiddenForm && sb.hiddenSsid === ""
      autoFocus: true; placeholder: "network name (ssid)"
      onAccepted: function(t) { sb.hiddenSsid = t.trim(); text = "" }
      onCancelled: sb.hiddenForm = false
    }
    Field {
      visible: col.wl && sb.hiddenForm && sb.hiddenSsid !== ""
      autoFocus: true; password: true; placeholder: "password for " + sb.hiddenSsid + "  (empty — open network)"
      onAccepted: function(t) { sb.md.connectHidden(sb.hiddenSsid, t); sb.hiddenForm = false; sb.hiddenSsid = ""; text = "" }
      onCancelled: sb.hiddenSsid = ""
    }
    Line { visible: col.wl && !sb.hiddenForm; text: "⟳ rescan"; onHit: sb.md.rescan() }

    // ── Wi-Fi: карточка сети ──
    readonly property bool wd: sb.page === "wifi" && sb.detail !== ""
    Line { visible: col.wd; text: "‹ " + sb.detailSsid; tail: sb.detailActive ? "connected" : "saved"; onHit: { sb.closeDetail(); sb.contentY = 0 } }
    Kv { visible: col.wd && sb.detailActive; k: "address"; v: sb.list(sb.info["IP4.ADDRESS"]).join("  ") }
    Kv { visible: col.wd && sb.detailActive; k: "gateway"; v: sb.info["IP4.GATEWAY"] || "" }
    Kv { visible: col.wd && sb.detailActive; k: "dns in use"; v: sb.list(sb.info["IP4.DNS"]).concat(sb.list(sb.info["IP6.DNS"])).join("  ") }
    Kv { visible: col.wd; k: "security"; v: sb.info["802-11-wireless-security.key-mgmt"] || "open" }
    Line { visible: col.wd; toggle: true; text: "connected"; on: sb.detailActive; tail: sb.detailActive ? "disconnect" : "connect"
      onHit: sb.detailActive ? sb.md.disconnectWifi(sb.detailSsid) : sb.md.connectWifi(sb.detailSsid, "") }
    Line { visible: col.wd; toggle: true; text: "auto-connect"; on: sb.info["connection.autoconnect"] === "yes"; tail: on ? "on" : "off"
      onHit: sb.md.setAutoconnect(sb.detail, !on) }
    Head { visible: col.wd; text: "dns" + (sb.detailActive ? " · applies now" : "") }
    Repeater {
      model: col.wd && sb.md ? sb.md.dnsPresets : []
      Line {
        required property var modelData
        toggle: true; text: modelData[0] === "auto" ? "auto (router)" : modelData[0]
        tail: modelData[1]
        on: sb.md.presetOf(sb.info) === modelData[0]
        onHit: sb.md.setDns(sb.detail, (modelData[1] + " " + modelData[2]).trim())
      }
    }
    Field {
      id: dnsField
      visible: col.wd
      placeholder: sb.md && sb.md.presetOf(sb.info) === "" && sb.md.dnsOf(sb.info) !== "" ? "custom: " + sb.md.dnsOf(sb.info) : "custom dns, e.g. 1.1.1.1 9.9.9.9  (enter — apply)"
      onAccepted: function(t) { if (t.trim().length) sb.md.setDns(sb.detail, t); text = "" }
    }
    Head { visible: col.wd; text: "password" }
    Line { visible: col.wd && sb.info["802-11-wireless-security.key-mgmt"] !== undefined && sb.info["802-11-wireless-security.key-mgmt"] !== ""
      text: "show password"; tail: sb.md && sb.md.psk !== "" ? sb.md.psk : "hidden"; onHit: sb.md.psk !== "" ? sb.md.psk = "" : sb.md.showPassword(sb.detail) }
    Field {
      visible: col.wd; password: true; placeholder: "new password  (enter — save and connect)"
      onAccepted: function(t) { if (t.length) sb.md.connectWifi(sb.detailSsid, t); text = "" }
    }
    Line { visible: col.wd; danger: true; text: sb.confirm === "forget" ? "press again to forget " + sb.detailSsid : "forget network"; on: sb.confirm === "forget"
      onHit: { if (sb.confirm === "forget") { sb.md.forget(sb.detail); sb.closeDetail(); sb.contentY = 0 } else sb.confirm = "forget" } }

    // ── Bluetooth ──
    readonly property bool bl: sb.page === "bt" && sb.btDetail === ""
    Line { visible: col.bl; toggle: true; text: "bluetooth"; on: !!sb.st && sb.st.bt; tail: sb.st && sb.st.bt ? "on" : "off"; onHit: sb.st.toggleBt() }
    Line { visible: col.bl; text: "⟳ scan for devices"; onHit: sb.md.scanBt() }
    Repeater {
      model: col.bl && sb.md ? sb.md.devices : []
      Line {
        required property var modelData
        text: modelData.name
        tail: (modelData.connected ? "connected" : modelData.paired ? "paired" : "new · pair") + (modelData.battery >= 0 ? "  " + modelData.battery + "%" : "")
        on: modelData.connected
        more: modelData.paired
        onHit: sb.md.toggleDevice(modelData)
        onMoreHit: { sb.btDetail = modelData.mac; sb.confirm = ""; sb.contentY = 0 }
      }
    }
    readonly property bool bd: sb.page === "bt" && sb.btDetail !== ""
    Line { visible: col.bd; text: "‹ " + (sb.dev ? sb.dev.name : ""); tail: sb.dev && sb.dev.battery >= 0 ? sb.dev.battery + "%" : ""; onHit: { sb.btDetail = ""; sb.confirm = "" } }
    Kv { visible: col.bd; k: "address"; v: sb.btDetail }
    Line { visible: col.bd; toggle: true; text: "connected"; on: !!sb.dev && sb.dev.connected; tail: on ? "disconnect" : "connect"; onHit: if (sb.dev) sb.md.toggleDevice(sb.dev) }
    Line { visible: col.bd; toggle: true; text: "trusted (auto-connect)"; on: !!sb.dev && sb.dev.trusted; tail: on ? "on" : "off"; onHit: if (sb.dev) sb.md.trustDevice(sb.dev, !sb.dev.trusted) }
    Line { visible: col.bd; danger: true; text: sb.confirm === "forget" ? "press again to forget" : "forget device"; on: sb.confirm === "forget"
      onHit: { if (sb.confirm === "forget") { sb.md.forgetDevice(sb.dev); sb.btDetail = ""; sb.confirm = "" } else sb.confirm = "forget" } }

    // ── Звук ──
    Slider { visible: sb.page === "audio"; label: "volume"; value: sb.st ? sb.st.vol : 0; onMoved: function(v) { sb.st.setVol(v) } }
    Line { visible: sb.page === "audio"; toggle: true; text: "microphone"; on: !!sb.st && !sb.st.micMuted; tail: sb.st && sb.st.micMuted ? "muted" : "on"; onHit: sb.st.toggleMic() }
    Slider { visible: sb.page === "audio"; label: "mic level"; value: sb.st ? sb.st.micVol : 0; onMoved: function(v) { sb.st.setMic(v) } }
    Head { visible: sb.page === "audio"; text: "output" }
    Repeater {
      model: sb.page === "audio" && sb.md ? sb.md.sinks : []
      Line {
        required property var modelData
        text: sb.md.sinkName(modelData)
        on: sb.md.defaultSink === modelData
        onHit: sb.md.setSink(modelData)
      }
    }
    Head { visible: sb.page === "audio" && sb.md && sb.md.sources.length > 0; text: "input" }
    Repeater {
      model: sb.page === "audio" && sb.md ? sb.md.sources : []
      Line {
        required property var modelData
        text: sb.md.sinkName(modelData)
        on: sb.md.defaultSource === modelData
        onHit: sb.md.setSource(modelData)
      }
    }
  }
}

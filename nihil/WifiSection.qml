import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "." as N
// Same parsing/sorting as the Omarchy network panel (Nihil clone kamradsmeshnyavy.network).
import "../../kamradsmeshnyavy.network/Model.js" as Model

// Expanded Wi-Fi section of the Nihil settings drawer — what the Omarchy network panel does:
// connection details and throughput, band, DNS, networks (password / 802.1X / forget), QR, speed test.
ColumnLayout {
  id: sec

  property var panel: null          // SettingsPanel, set by its Loader
  function tr(en, ru) { return panel ? panel.host.tr(en, ru) : en }

  spacing: 8

  // ── NetworkManager через Quickshell.Networking, как в стоковой панели ──────
  readonly property var devices: Networking.devices ? Networking.devices.values : []
  readonly property var wifiDevice: {
    var fallback = null
    for (var i = 0; i < devices.length; i++) {
      var d = devices[i]
      if (!d || d.type !== DeviceType.Wifi) continue
      if (d.connected) return d
      if (!fallback) fallback = d
    }
    return fallback
  }
  readonly property var networkObjects: wifiDevice && wifiDevice.networks ? wifiDevice.networks.values : []

  // Primitive rows only (see Model.wifiRow): live WifiNetwork objects can die under a delegate.
  property var rows: []
  function syncRows() {
    var out = []
    for (var i = 0; i < networkObjects.length; i++) {
      var r = Model.wifiRow(networkObjects[i])
      if (r && r.ssid) out.push(r)
    }
    rows = Model.sortWifiRows(out).slice(0, 12)
  }
  function networkFor(ssid) {
    for (var i = 0; i < networkObjects.length; i++)
      if (networkObjects[i] && networkObjects[i].name === ssid) return networkObjects[i]
    return null
  }
  function needsCredentials(row) {
    return Model.requiresCredentials(row.security, WifiSecurityType.Open, WifiSecurityType.Owe)
  }
  function isEnterprise(row) {
    return row.security === WifiSecurityType.Wpa2Eap || row.security === WifiSecurityType.WpaEap
  }

  property string promptSsid: ""
  property string busySsid: ""
  property real busySince: 0
  onBusySsidChanged: busySince = Date.now()
  property string failure: ""

  function activate(row) {
    failure = ""
    var net = networkFor(row.ssid)
    if (!net) return
    if (row.connected) { busySsid = row.ssid; net.disconnect(); return }
    if (needsCredentials(row) && !row.known) { promptSsid = row.ssid; return }
    busySsid = row.ssid
    net.connect()
  }
  function submit(row, identity, password) {
    var net = networkFor(row.ssid)
    if (!net || password === "") return
    busySsid = row.ssid
    promptSsid = ""
    if (isEnterprise(row)) {
      enterpriseProc.secret = password
      enterpriseProc.command = ["bash", "-c", Model.enterpriseConnectScript, "nmcli-eap", row.ssid, identity]
      enterpriseProc.running = true
    } else {
      net.connectWithPsk(password)
    }
  }
  function forget(row) {
    var net = networkFor(row.ssid)
    if (net && Model.canForgetNetwork(row)) { busySsid = row.ssid; net.forget() }
  }

  // ── Сведения о подключении: omarchy-network-status --verbose ──────────────
  property var info: ({})
  property var prevSample: null
  property real rxRate: 0
  property real txRate: 0
  property var rxHistory: []
  property var txHistory: []
  function updateInfo(raw) {
    var next = Model.parseKeyValue(raw)
    var now = Date.now()
    var rx = Number(next.rx_bytes), tx = Number(next.tx_bytes)
    if (prevSample && prevSample.iface === next.iface && now > prevSample.t && isFinite(rx) && isFinite(tx)) {
      var dt = (now - prevSample.t) / 1000
      rxRate = Math.max(0, (rx - prevSample.rx) / dt)
      txRate = Math.max(0, (tx - prevSample.tx) / dt)
      rxHistory = rxHistory.concat([rxRate]).slice(-44)
      txHistory = txHistory.concat([txRate]).slice(-44)
    }
    prevSample = { iface: next.iface, rx: rx, tx: tx, t: now }
    info = next
  }

  // ── Диапазон и DNS ────────────────────────────────────────────────────────
  property var band: ({ band: "", selected: "auto", available: [] })
  property string dns: ""
  readonly property var dnsProviders: ["DHCP", "Cloudflare", "Google", "Custom"]
  function setBand(b) {
    if (actionProc.running) return
    band = { band: band.band, selected: b, available: band.available }
    actionProc.command = ["omarchy-network-band", b]
    actionProc.running = true
  }
  function setDns(p) {
    if (p === "Custom") {
      panel.host.settingsOpen = false
      Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "omarchy-dns Custom"])
      return
    }
    if (actionProc.running) return
    dns = p
    actionProc.command = ["omarchy-dns", p]
    actionProc.running = true
  }
  function summon(id, payload) {
    panel.host.settingsOpen = false
    Quickshell.execDetached(["omarchy-shell", "shell", "toggle", id, JSON.stringify(payload || {})])
  }

  Process { id: detailsProc; command: ["omarchy-network-status", "--verbose"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: sec.updateInfo(text) } }
  Process { id: bandProc; command: ["omarchy-network-band"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: sec.band = Model.parseBandStatus(text) } }
  Process { id: dnsProc; command: ["omarchy-dns"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: sec.dns = String(text || "").trim() || "DHCP" } }
  Process { id: actionProc; onExited: { bandProc.running = true; dnsProc.running = true } }
  // 802.1X profile; the password goes over stdin, never argv (Model.enterpriseConnectScript).
  Process {
    id: enterpriseProc
    property string secret: ""
    stdinEnabled: true
    onStarted: { write(secret + "\n"); secret = "" }
    onExited: function(code) { if (code !== 0) sec.failure = sec.tr("Could not connect", "Не удалось подключиться"); sec.busySsid = "" }
  }

  Timer {
    interval: 1500; running: sec.visible; repeat: true; triggeredOnStart: true
    onTriggered: {
      if (!detailsProc.running) detailsProc.running = true
      sec.syncRows()
      // The action is over once NetworkManager stopped changing the network's state.
      if (sec.busySsid !== "" && Date.now() - sec.busySince > 2500) {
        var n = sec.networkFor(sec.busySsid)
        if (!n || !n.stateChanging) sec.busySsid = ""
      }
    }
  }
  Timer {
    interval: 4000; running: sec.visible; repeat: true; triggeredOnStart: true
    onTriggered: { if (!bandProc.running) bandProc.running = true; if (!dnsProc.running) dnsProc.running = true }
  }
  // Scanning only while the section is open, like the stock panel.
  onVisibleChanged: if (wifiDevice) wifiDevice.scannerEnabled = visible
  Component.onCompleted: if (wifiDevice) wifiDevice.scannerEnabled = visible
  Component.onDestruction: if (wifiDevice) wifiDevice.scannerEnabled = false

  // ── Вид ───────────────────────────────────────────────────────────────────
  RowLayout {
    Layout.fillWidth: true
    N.Label {
      Layout.fillWidth: true
      text: sec.info.iface ? (String(sec.info.type || "").toUpperCase() + " · " + sec.info.iface) : sec.tr("NOT CONNECTED", "НЕТ ПОДКЛЮЧЕНИЯ")
    }
    N.PillButton { text: "QR"; visible: sec.info.type === "wifi"; onClicked: sec.summon("omarchy.wifiqr", { iface: sec.info.iface, ssid: sec.info.ssid }) }
    N.PillButton {
      text: sec.tr("SPEED TEST", "ТЕСТ")
      onClicked: sec.summon("omarchy.speedtest", { connection: sec.info.type === "wifi" ? (sec.info.ssid || "Wi-Fi") : "Ethernet" })
    }
  }

  // Throughput: LED scope + numbers
  N.DotScope {
    Layout.fillWidth: true
    visible: !!sec.info.iface
    implicitHeight: 40
    series: sec.rxHistory
    secondary: sec.txHistory
  }

  GridLayout {
    Layout.fillWidth: true
    visible: !!sec.info.iface
    columns: 4
    columnSpacing: 10
    rowSpacing: 4

    N.Label { text: "↓" }

    N.Txt { Layout.fillWidth: true; text: Model.formatRate(sec.rxRate); font.pixelSize: 12 }
    N.Label { text: "↑" }
    N.Txt { Layout.fillWidth: true; text: Model.formatRate(sec.txRate); font.pixelSize: 12 }
    N.Label { text: "IP" }
    N.Txt { Layout.fillWidth: true; text: sec.info.ip ? sec.info.ip + "/" + (sec.info.prefix || "") : "--"; font.pixelSize: 12 }
    N.Label { text: sec.tr("GW", "ШЛЮЗ") }
    N.Txt { Layout.fillWidth: true; text: sec.info.gateway || "--"; font.pixelSize: 12 }
    N.Label { text: sec.tr("LINK", "ЛИНК") }
    N.Txt {
      Layout.fillWidth: true; font.pixelSize: 12
      text: sec.info.type === "wifi"
        ? ((sec.info.signal ? sec.info.signal + "% · " : "") + (Model.formatHeaderFreq(Number(sec.info.freq)) || "") + (sec.info.bitrate ? " · " + sec.info.bitrate : ""))
        : (Model.formatHeaderSpeed(Number(sec.info.speed)) || "--")
    }
    N.Label { text: sec.tr("PING", "ПИНГ") }
    N.Txt {
      Layout.fillWidth: true; font.pixelSize: 12
      text: (sec.info.internet_ping_ms ? Math.round(Number(sec.info.internet_ping_ms)) + " ms" : "--")
        + (sec.info.router_ping_ms ? " · " + sec.tr("router", "роутер") + " " + Math.round(Number(sec.info.router_ping_ms)) + " ms" : "")
    }
  }

  // Band (only with a Wi-Fi station that can switch)
  N.Label { text: sec.tr("BAND", "ДИАПАЗОН"); visible: sec.band.available.length > 0; Layout.topMargin: 4 }
  Flow {
    Layout.fillWidth: true
    visible: sec.band.available.length > 0
    spacing: 6
    Repeater {
      model: ["auto"].concat(sec.band.available)
      N.PillButton {
        required property string modelData
        text: Model.bandLabel(modelData)
        accent: sec.band.selected === modelData
        onClicked: sec.setBand(modelData)
      }
    }
  }

  N.Label { text: "DNS"; Layout.topMargin: 4 }
  Flow {
    Layout.fillWidth: true
    spacing: 6
    Repeater {
      model: sec.dnsProviders
      N.PillButton {
        required property string modelData
        text: modelData
        accent: sec.dns === modelData
        onClicked: sec.setDns(modelData)
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    N.Label { text: sec.wifiDevice ? sec.tr("NETWORKS", "СЕТИ") : sec.tr("NO WI-FI ADAPTER", "НЕТ WI-FI АДАПТЕРА") }
    Item { Layout.fillWidth: true }
    N.CircleButton {
      glyph: String.fromCodePoint(0xF0493)
      size: 28
      onClicked: { sec.panel.host.settingsOpen = false; Quickshell.execDetached(["omarchy-shell", "omarchy.network", "open"]) }
    }
  }

  Repeater {
    model: sec.rows

    ColumnLayout {
      id: netItem
      required property var modelData
      Layout.fillWidth: true
      spacing: 4

      N.ListRow {
        glyph: Model.wifiIconFor(netItem.modelData.signal)
        title: netItem.modelData.ssid
        subtitle: netItem.modelData.connected ? sec.tr("CONNECTED", "ПОДКЛЮЧЕНО")
          : (netItem.modelData.known ? sec.tr("SAVED", "СОХРАНЕНА") : "")
        detail: sec.needsCredentials(netItem.modelData) && !netItem.modelData.connected ? String.fromCodePoint(0xF033E) : ""
        current: netItem.modelData.connected
        busy: sec.busySsid === netItem.modelData.ssid
        action: Model.canForgetNetwork(netItem.modelData) || netItem.modelData.connected ? String.fromCodePoint(0xF0156) : ""
        actionDanger: true
        onClicked: sec.activate(netItem.modelData)
        onActionClicked: netItem.modelData.connected ? sec.activate(netItem.modelData) : sec.forget(netItem.modelData)
      }

      // Inline credentials: 802.1X asks for identity too.
      ColumnLayout {
        Layout.fillWidth: true
        visible: sec.promptSsid === netItem.modelData.ssid
        spacing: 4

        Field {
          id: idField
          visible: sec.isEnterprise(netItem.modelData)
          placeholder: sec.tr("Identity (user@domain)", "Логин (user@domain)")
          onAccepted: pwField.focusField()
        }
        Field {
          id: pwField
          password: true
          placeholder: sec.tr("Password", "Пароль")
          onAccepted: sec.submit(netItem.modelData, idField.text, text)
        }
        onVisibleChanged: if (visible) (idField.visible ? idField : pwField).focusField()
      }
    }
  }

  N.Label { visible: sec.failure !== ""; text: sec.failure; color: N.Palette.danger }

  component Field: Rectangle {
    id: fld
    property string placeholder: ""
    property bool password: false
    property alias text: input.text
    signal accepted()
    function focusField() { input.text = ""; input.forceActiveFocus() }

    Layout.fillWidth: true
    implicitHeight: 36
    radius: N.Finish.nihil ? 18 : N.Finish.radius
    color: N.Palette.surface
    border.width: 1
    border.color: input.activeFocus ? N.Palette.dim : N.Palette.line

    QQC.TextField {
      id: input
      anchors.fill: parent
      anchors.leftMargin: 14
      anchors.rightMargin: 14
      background: null
      echoMode: fld.password ? TextInput.Password : TextInput.Normal
      color: N.Palette.fg
      placeholderText: fld.placeholder
      placeholderTextColor: N.Palette.muted
      font.family: N.Finish.labelFont
      font.pixelSize: 12
      verticalAlignment: TextInput.AlignVCenter
      onAccepted: fld.accepted()
      Keys.onEscapePressed: sec.promptSsid = ""
    }
  }
}

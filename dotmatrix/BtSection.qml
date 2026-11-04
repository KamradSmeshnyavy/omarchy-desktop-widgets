import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import "." as N
// Same grouping and labels as the Omarchy Bluetooth panel (DOT-MATRIX clone kamradsmeshnyavy.bluetooth).
import "../../kamradsmeshnyavy.bluetooth/Model.js" as Model

// Expanded Bluetooth section of the DOT-MATRIX settings drawer — what the Omarchy Bluetooth panel does:
// power, scan, connected / paired / found devices, connect, pair, disconnect, forget, audio output.
ColumnLayout {
  id: sec

  property var panel: null          // SettingsPanel, set by its Loader
  function tr(en, ru) { return panel ? panel.host.tr(en, ru) : en }

  spacing: 6

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool powered: adapter ? adapter.enabled : false
  readonly property bool discovering: adapter ? adapter.discovering : false

  // Snapshot rows on a timer, never straight off the live model (device removal mid-signal
  // has crashed Quickshell in the stock panels too).
  property var groups: ({ connected: [], known: [], discovered: [] })
  function allDevices() { return Bluetooth.devices ? Bluetooth.devices.values : [] }
  function sync() { groups = Model.deviceLists(allDevices()) }
  function deviceFor(address) {
    var all = Model.toArray(allDevices())
    for (var i = 0; i < all.length; i++) if (all[i] && all[i].address === address) return all[i]
    return null
  }

  property var pending: ({})
  function setPending(address, action) { pending = Model.withPendingAction(pending, address, action) }
  function run(device, action, label) {
    if (!device || !device.address) return
    setPending(device.address, label)
    Quickshell.execDetached(["omarchy-bluetooth-device", action, device.address])
  }
  function connect(d) {
    if (!d || d.connected) return
    if (d.paired || d.bonded || d.trusted) run(d, "connect", "connecting")
    else run(d, "pair", "connecting")
  }
  function disconnect(d) {
    if (!d || !d.connected) return
    setPending(d.address, "disconnecting")
    if (d.disconnect) d.disconnect()
    Quickshell.execDetached(["omarchy-bluetooth-device", "disconnect", d.address])
  }
  function forget(d) { run(d, "forget", "forgetting") }

  // A connected headset is a PipeWire sink; offer to make it the default output.
  function sinkFor(d) {
    var nodes = Pipewire.nodes && Pipewire.nodes.values ? Pipewire.nodes.values : []
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (n && n.isSink && !n.isStream && n.audio && Model.bluetoothSinkMatchesDevice(n, d)) return n
    }
    return null
  }
  function useAsOutput(d) {
    var s = sinkFor(d)
    if (!s) return
    Pipewire.preferredDefaultAudioSink = s
    Quickshell.execDetached(["omarchy-audio-output-set-default", String(s.id), String(s.name)])
  }

  Timer {
    interval: 1000; running: sec.visible; repeat: true; triggeredOnStart: true
    onTriggered: {
      sec.sync()
      // Pending actions end when the device settles.
      var next = Model.cloneMap(sec.pending)
      for (var a in next) {
        var d = sec.deviceFor(a)
        var p = next[a]
        if (!d || (p === "connecting" && d.connected) || (p === "disconnecting" && !d.connected)
            || (p === "forgetting" && !d.paired)) delete next[a]
      }
      sec.pending = next
    }
  }
  // Scan while the section is open, like the stock panel.
  onVisibleChanged: if (adapter && powered) adapter.discovering = visible
  Component.onCompleted: if (adapter && powered && visible) adapter.discovering = true
  Component.onDestruction: if (adapter) adapter.discovering = false

  RowLayout {
    Layout.fillWidth: true
    N.Label {
      text: !sec.adapter ? sec.tr("NO ADAPTER", "НЕТ АДАПТЕРА")
        : !sec.powered ? sec.tr("BLUETOOTH OFF", "BLUETOOTH ВЫКЛЮЧЕН")
        : sec.discovering ? sec.tr("SCANNING…", "ПОИСК…") : sec.tr("DEVICES", "УСТРОЙСТВА")
    }
    Item { Layout.fillWidth: true }
    N.PillButton {
      visible: !!sec.adapter
      text: sec.powered ? sec.tr("TURN OFF", "ВЫКЛ") : sec.tr("TURN ON", "ВКЛ")
      onClicked: Quickshell.execDetached(["omarchy-bluetooth-power", sec.powered ? "off" : "on"])
    }
    N.CircleButton {
      visible: sec.powered
      glyph: String.fromCodePoint(0xF0450)
      size: 28
      filled: sec.discovering
      onClicked: if (sec.adapter) sec.adapter.discovering = !sec.discovering
    }
    N.CircleButton {
      glyph: String.fromCodePoint(0xF0493)
      size: 28
      onClicked: { sec.panel.host.settingsOpen = false; Quickshell.execDetached(["omarchy-shell", "omarchy.bluetooth", "open"]) }
    }
  }

  Repeater {
    model: [
      { key: "connected", en: "CONNECTED", ru: "ПОДКЛЮЧЕНЫ" },
      { key: "known", en: "PAIRED", ru: "СОПРЯЖЕНЫ" },
      { key: "discovered", en: "FOUND", ru: "НАЙДЕНЫ" }
    ]

    ColumnLayout {
      id: group
      required property var modelData
      readonly property var list: !sec.powered || (modelData.key === "discovered" && !sec.discovering) ? [] : (sec.groups[modelData.key] || [])
      Layout.fillWidth: true
      visible: list.length > 0
      spacing: 2

      N.Label { text: sec.tr(group.modelData.en, group.modelData.ru); color: N.Palette.dim; Layout.topMargin: 4 }

      Repeater {
        model: group.list

        N.ListRow {
          id: devRow
          required property var modelData
          readonly property string address: modelData.address || ""
          readonly property string state: Model.pendingAction(sec.pending, address)
          readonly property bool audio: group.modelData.key === "connected" && sec.sinkFor(modelData) !== null
          glyph: modelData.connected ? String.fromCodePoint(0xF00B1) : String.fromCodePoint(0xF00AF)
          title: Model.deviceLabel(modelData)
          subtitle: devRow.state === "connecting" ? sec.tr("CONNECTING…", "ПОДКЛЮЧЕНИЕ…")
            : devRow.state === "disconnecting" ? sec.tr("DISCONNECTING…", "ОТКЛЮЧЕНИЕ…")
            : devRow.state === "forgetting" ? sec.tr("FORGETTING…", "УДАЛЕНИЕ…")
            : (modelData.batteryAvailable ? sec.tr("BATTERY ", "БАТАРЕЯ ") + Math.round(modelData.battery * 100) + "%" : "")
          detail: devRow.audio ? String.fromCodePoint(0xF04C3) : ""
          current: modelData.connected
          busy: devRow.state !== ""
          // Forget for paired devices; for a connected headset the button makes it the output.
          action: group.modelData.key === "discovered" ? "" : (devRow.audio ? String.fromCodePoint(0xF057E) : String.fromCodePoint(0xF0156))
          actionDanger: !devRow.audio
          onClicked: {
            var d = sec.deviceFor(address)
            if (!d) return
            if (d.connected) sec.disconnect(d)
            else sec.connect(d)
          }
          onActionClicked: {
            var d = sec.deviceFor(address)
            if (!d) return
            if (devRow.audio) sec.useAsOutput(d)
            else sec.forget(d)
          }
        }
      }
    }
  }

  N.Label {
    visible: sec.powered && sec.groups.connected.length + sec.groups.known.length + (sec.discovering ? sec.groups.discovered.length : 0) === 0
    text: sec.tr("NO DEVICES", "НЕТ УСТРОЙСТВ")
  }
}

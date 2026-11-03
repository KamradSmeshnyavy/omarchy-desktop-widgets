import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "." as N
// Same node filtering and labels as the Omarchy audio panel (Nihil clone kamradsmeshnyavy.audio).
import "../../kamradsmeshnyavy.audio/Model.js" as Model

// Expanded sound section of the Nihil settings drawer — what the Omarchy audio panel does:
// output and input devices (default, volume, mute) and per-application volume.
ColumnLayout {
  id: sec

  property var panel: null          // SettingsPanel, set by its Loader
  function tr(en, ru) { return panel ? panel.host.tr(en, ru) : en }

  spacing: 6

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource

  // Repeaters read snapshots refreshed on a timer, never the live PipeWire list: rebuilding
  // a Repeater from the node-removed signal path has crashed Quickshell (see the stock panel).
  property var sinks: []
  property var sources: []
  property var streams: []
  function sync() {
    var nodes = Pipewire.nodes && Pipewire.nodes.values ? Pipewire.nodes.values : []
    var outs = [], ins = [], apps = []
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (!n) continue
      if (n.isStream) {
        if (Model.isPlaybackStream(n) && n.audio && String(n.name || "").indexOf("omarchy_speaker_tuning") !== 0) apps.push(n)
      } else if (n.isSink) {
        // Unplugged HDMI / jack outputs are hidden, like in the stock panel.
        if (n === sec.sink || !sinkAvailabilityLoaded || sinkAvailability[String(n.name)] !== false) outs.push(n)
      } else if (Model.isAudioSource(n) && n.name !== "quickshell") {
        ins.push(n)
      }
    }
    sinks = outs
    sources = ins
    streams = apps
  }

  property var sinkAvailability: ({})
  property bool sinkAvailabilityLoaded: false
  Process {
    id: availabilityProc
    command: ["omarchy-audio-sink-availability"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: { sec.sinkAvailability = Model.parseSinkAvailability(text); sec.sinkAvailabilityLoaded = true }
    }
  }
  Timer { interval: 5000; running: sec.visible; repeat: true; triggeredOnStart: true; onTriggered: if (!availabilityProc.running) availabilityProc.running = true }

  PwObjectTracker { objects: sec.sinks.concat(sec.sources, sec.streams) }

  function setDefaultSink(n) {
    Pipewire.preferredDefaultAudioSink = n
    Quickshell.execDetached(["omarchy-audio-output-set-default", String(n.id), String(n.name)])
  }
  function setDefaultSource(n) {
    Pipewire.preferredDefaultAudioSource = n
    Quickshell.execDetached(["omarchy-audio-input-set-default", String(n.id), String(n.name)])
  }
  function setVolume(n, v) {
    if (!n || !n.audio) return
    n.audio.muted = false
    n.audio.volume = Math.max(0, Math.min(1, v))
  }
  function toggleMute(n) { if (n && n.audio) n.audio.muted = !n.audio.muted }
  function streamName(n) {
    var players = Mpris.players ? Mpris.players.values : []
    return Model.streamLabel(n, players, sec.streams)
  }

  Timer { interval: 800; running: sec.visible; repeat: true; triggeredOnStart: true; onTriggered: sec.sync() }

  RowLayout {
    Layout.fillWidth: true
    N.Label { text: sec.tr("OUTPUT", "ВЫХОД") }
    Item { Layout.fillWidth: true }
    N.CircleButton {
      glyph: String.fromCodePoint(0xF0493)
      size: 28
      onClicked: { sec.panel.host.settingsOpen = false; Quickshell.execDetached(["omarchy-shell", "omarchy.audio", "open"]) }
    }
  }

  Repeater {
    model: sec.sinks
    N.ListRow {
      required property var modelData
      glyph: Model.sinkGlyph(modelData)
      title: Model.nodeLabel(modelData)
      current: sec.sink === modelData
      detail: modelData.audio ? Math.round(modelData.audio.volume * 100) + "%" : ""
      onClicked: sec.setDefaultSink(modelData)
    }
  }

  N.Label { text: sec.tr("INPUT", "ВХОД"); Layout.topMargin: 6 }

  Repeater {
    model: sec.sources
    N.ListRow {
      required property var modelData
      glyph: Model.sourceGlyph(modelData)
      title: Model.nodeLabel(modelData)
      current: sec.source === modelData
      detail: modelData.audio ? (modelData.audio.muted ? sec.tr("MUTED", "ВЫКЛ") : Math.round(modelData.audio.volume * 100) + "%") : ""
      action: String.fromCodePoint(modelData.audio && modelData.audio.muted ? 0xF036D : 0xF036C)
      onClicked: sec.setDefaultSource(modelData)
      onActionClicked: sec.toggleMute(modelData)
    }
  }

  RowLayout {
    Layout.fillWidth: true
    Layout.topMargin: 6
    visible: sec.streams.length > 0
    N.Label { text: sec.tr("APPLICATIONS", "ПРИЛОЖЕНИЯ") }
    Item { Layout.fillWidth: true }
    N.PillButton {
      readonly property bool allMuted: {
        for (var i = 0; i < sec.streams.length; i++) if (sec.streams[i].audio && !sec.streams[i].audio.muted) return false
        return sec.streams.length > 0
      }
      text: allMuted ? sec.tr("UNMUTE ALL", "ВКЛ. ВСЕ") : sec.tr("MUTE ALL", "ВЫКЛ. ВСЕ")
      onClicked: {
        var mute = !allMuted
        for (var i = 0; i < sec.streams.length; i++) if (sec.streams[i].audio) sec.streams[i].audio.muted = mute
      }
    }
  }

  Repeater {
    model: sec.streams

    ColumnLayout {
      id: app
      required property var modelData
      Layout.fillWidth: true
      spacing: 2

      N.Txt { text: sec.streamName(app.modelData); color: N.Palette.dim; font.pixelSize: 12; Layout.fillWidth: true }
      N.SliderRow {
        Layout.fillWidth: true
        glyph: String.fromCodePoint(app.modelData.audio && app.modelData.audio.muted ? 0xF075F : 0xF057E)
        value: app.modelData.audio ? app.modelData.audio.volume : 0
        muted: app.modelData.audio ? app.modelData.audio.muted : false
        onMoved: function(v) { sec.setVolume(app.modelData, v) }
        onGlyphClicked: sec.toggleMute(app.modelData)
      }
    }
  }
}

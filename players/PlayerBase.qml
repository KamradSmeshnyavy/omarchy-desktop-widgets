import QtQuick
import qs.Commons as Commons

// Основа вида панели плеера (PlayerHost.qml): данные и показ, как у плеера Unit-3, — вид рисует только облик.
//   mpTitle / mpArtist / mpCoverUrl / mpPlaying / mpPosition (с) / mpLength (с), levels — уровни визуализатора (cava);
//   сигналы playPause / nextTrack / prevTrack / seek(secs); shown + toggleVisible() — въезд справа с затуханием.
// Цвета темы — fg / bg / accent / urgent; fmt(с) — «м:сс»; frac — доля проигранного.
Item {
  id: base
  property string mpTitle: ""
  property string mpArtist: ""
  property string mpCoverUrl: ""
  property bool mpPlaying: false
  property real mpPosition: 0
  property real mpLength: 1
  property var levels: []
  signal playPause
  signal nextTrack
  signal prevTrack
  signal seek(real secs)

  property bool shown: false
  function toggleVisible() { shown = !shown }
  property real k: shown ? 1 : 0
  Behavior on k { NumberAnimation { duration: base.shown ? 420 : 300; easing.type: base.shown ? Easing.OutExpo : Easing.InCubic } }
  opacity: k
  transform: Translate { x: (1 - base.k) * 60 }

  readonly property color fg: Commons.Color.foreground
  readonly property color bg: Commons.Color.background
  readonly property color accent: Commons.Color.accent
  readonly property color urgent: Commons.Color.urgent
  readonly property bool dark: 0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b < 0.5
  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
  function mix(a, c, t) { return Qt.rgba(a.r + (c.r - a.r) * t, a.g + (c.g - a.g) * t, a.b + (c.b - a.b) * t, 1) }
  function fmt(x) { x = Math.max(0, Math.floor(x || 0)); return Math.floor(x / 60) + ":" + ("0" + (x % 60)).slice(-2) }
  readonly property real frac: mpLength > 0 ? Math.max(0, Math.min(1, mpPosition / mpLength)) : 0
  function level(i, n) { var l = levels || []; return l.length ? Math.min(1, Number(l[Math.floor(i * l.length / n)] || 0)) : (mpPlaying ? 0.15 + 0.1 * Math.abs(Math.sin(i * 1.7)) : 0.05) }
  function font(name, fallback) { return Qt.fontFamilies().indexOf(name) !== -1 ? name : fallback }
  function act(i) { if (i === 0) prevTrack(); else if (i === 1) playPause(); else nextTrack() }
  function seekAt(x, w) { seek(Math.max(0, Math.min(1, x / w)) * mpLength) }
}

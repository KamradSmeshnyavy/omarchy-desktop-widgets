import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris

// Панель плеера у каждого райса (Super+Alt+M → omarchy-shell widgets togglePlayer). Окно справа на 39 % высоты экрана
// с фокусом мыши, вид — по райсу (playerStyle: auto → partFor), файл players/Player<Вид>.qml. Данные — MPRIS
// (Quickshell.Services.Mpris): играющий плеер, иначе первый с треком. API вида (как у плеера Unit-3):
//   свойства mpTitle, mpArtist, mpCoverUrl, mpPlaying, mpPosition (с), mpLength (с), shown;
//   сигналы playPause, nextTrack, prevTrack, seek(secs); функция toggleVisible() — показать / спрятать со своей анимацией.
// Окно живёт ещё 700 мс после закрытия, чтобы вид успел доиграть уход; щелчки сквозь пустое место проходят (mask).
PanelWindow {
  id: win
  required property var host

  // вид: playerStyle из widgets.json, auto — по райсу (style.json «rice» / «id»), без райса — surface (цвета темы)
  readonly property var files: ({
    unit3: "players/PlayerUnit3.qml", bruteon: "players/PlayerBruteon.qml", cozytile: "players/PlayerCozytile.qml",
    rumda: "players/PlayerRumda.qml", surface: "players/PlayerSurface.qml", yami: "players/PlayerYami.qml",
    dotmatrix: "players/PlayerDots.qml", glyph: "players/PlayerDots.qml", vitreus: "players/PlayerVitreus.qml",
    space: "players/PlayerSpace.qml", crt: "players/PlayerCrt.qml", modern: "players/PlayerModern.qml"
  })
  readonly property string style: {
    var v = String(host.value("playerStyle") || "auto")
    if (files[v]) return v
    return files[host.rice] ? host.rice : "surface"
  }

  readonly property var player: {
    var l = Mpris.players.values
    for (var i = 0; i < l.length; i++) if (l[i].isPlaying && l[i].trackTitle) return l[i]
    for (var j = 0; j < l.length; j++) if (l[j].trackTitle) return l[j]
    return l.length ? l[0] : null
  }
  // позиция MPRIS сама не обновляется — дёргаем раз в секунду, пока панель на экране
  Timer { interval: 1000; repeat: true; running: win.visible && !!win.player; onTriggered: if (win.player) win.player.positionChanged() }

  screen: host.focusedScreen
  anchors { top: true; right: true }
  margins.top: screen ? Math.round(screen.height * 0.39) : 300
  margins.right: 20
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  implicitWidth: view.item ? Math.max(1, view.item.implicitWidth) : 1
  implicitHeight: view.item ? Math.max(1, view.item.implicitHeight) : 1
  WlrLayershell.namespace: "omarchy-player"
  WlrLayershell.layer: WlrLayer.Top
  visible: host.playerOpen || linger.running
  mask: Region { item: host.playerOpen ? view : null }

  Timer { id: linger; interval: 700 }
  Connections {
    target: win.host
    function onPlayerOpenChanged() {
      if (!win.host.playerOpen) linger.restart()
      if (view.item && view.item.shown !== win.host.playerOpen) view.item.toggleVisible()
    }
  }

  Loader {
    id: view
    anchors.fill: parent
    source: win.files[win.style]
    onLoaded: if (win.host.playerOpen && !item.shown) item.toggleVisible()
  }
  Binding { when: !!view.item; target: view.item; property: "mpTitle"; value: win.player && win.player.trackTitle ? win.player.trackTitle : "NO SIGNAL" }
  Binding { when: !!view.item; target: view.item; property: "mpArtist"; value: win.player && win.player.trackArtist ? win.player.trackArtist : "— // —" }
  Binding { when: !!view.item; target: view.item; property: "mpCoverUrl"; value: win.player ? String(win.player.trackArtUrl || "") : "" }
  Binding { when: !!view.item; target: view.item; property: "mpPlaying"; value: !!win.player && win.player.isPlaying }
  Binding { when: !!view.item; target: view.item; property: "mpPosition"; value: win.player ? win.player.position : 0 }
  Binding { when: !!view.item && view.item.levels !== undefined; target: view.item; property: "levels"; value: win.host.levels }
  Binding { when: !!view.item; target: view.item; property: "mpLength"; value: win.player && win.player.length > 0 ? win.player.length : 1 }
  Connections {
    target: view.item
    ignoreUnknownSignals: true
    function onPlayPause() { if (win.player) win.player.togglePlaying() }
    function onNextTrack() { if (win.player) win.player.next() }
    function onPrevTrack() { if (win.player) win.player.previous() }
    function onSeek(secs) { if (win.player && win.player.canSeek) win.player.position = secs }
  }
}

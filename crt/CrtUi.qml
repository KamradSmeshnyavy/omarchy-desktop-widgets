pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Шрифт и размер текста Retro CRT — его retro.font / retro.size (Retro/common/Theme.qml); пишет панель настроек
// (CORE → Text size, Font) в ~/.config/omarchy/crt.json → ui. Пусто — Terminess, 14.
Singleton {
  id: ui
  property string font: ""
  property int size: 0
  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy/crt.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: { try { var u = JSON.parse(text()).ui || {}; ui.font = String(u.font || ""); ui.size = Number(u.size) || 0 } catch (e) {} }
  }
}

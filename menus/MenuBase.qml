import QtQuick
import Quickshell

// Основа содержимого меню Super+M райса (MenuShell.qml): host, md (MenuData), k — 0…1 появление, open; page — открытый
// раздел ("" — главный вид); section(name) открывает wifi / bt / audio по openSettingsSection; back() — назад из раздела;
// body — SectionBody меню: Esc сначала закрывает в нём поле / карточку (MenuShell), потом уже раздел.
Item {
  id: mb
  property var host: null
  property var md: null
  property real k: 0
  property bool open: false
  property string page: ""
  property Item body: null
  onOpenChanged: if (!open) page = ""
  function section(name) { page = ({ wifi: "wifi", bt: "bt", bluetooth: "bt", audio: "audio" })[name] || "" }
  function back() { if (page !== "") { page = ""; return true } return false }
  function close() { if (host) host.settingsOpen = false }
  function run(a) { Quickshell.execDetached(a) }
  readonly property var st: md ? md.st : null
}

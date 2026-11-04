import QtQuick
import "dotmatrix" as DotMatrix

// Сеть на рабочем столе: интерфейс по умолчанию, скорость ↓ / ↑ и точечный осциллограф (DotScope).
// По карточке «network» рабочего стола NIHIL (home/shell/background/Desktop.qml, poligle/Nihil-Shell, MIT).
// Данные — host.netIface / rxRate / txRate / rxHistory / txHistory (опрос раз в 2 с в Widgets.qml).
Item {
  id: net

  required property var host
  readonly property bool dotmatrix: host.dotmatrixWidgets
  readonly property string face: dotmatrix ? DotMatrix.Palette.fontMono : host.fontFamily

  width: 284
  height: col.implicitHeight

  function rate(bytes) {
    var b = Math.max(0, Number(bytes || 0))
    if (b >= 1048576) return (b / 1048576).toFixed(1) + " MB/S"
    if (b >= 1024) return Math.round(b / 1024) + " KB/S"
    return Math.round(b) + " B/S"
  }

  Column {
    id: col
    width: parent.width
    spacing: 10

    Item {
      width: parent.width
      height: Math.max(iface.implicitHeight, speeds.implicitHeight)

      DotMatrix.Label {
        id: iface
        visible: net.dotmatrix
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - speeds.width - 12
        text: net.host.netIface || net.host.tr("offline", "нет сети")
      }
      Text {
        visible: !net.dotmatrix
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - speeds.width - 12
        elide: Text.ElideRight
        text: net.host.netIface || net.host.tr("offline", "нет сети")
        color: net.host.foreground
        font.family: net.face
        font.pixelSize: 14
        font.weight: Font.DemiBold
      }

      Row {
        id: speeds
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10
        Text {
          text: "↓ " + net.rate(net.host.rxRate)
          color: net.dotmatrix ? DotMatrix.Palette.dim : net.host.muted
          font.family: net.face
          font.pixelSize: 11
          font.letterSpacing: net.dotmatrix ? 1 : 0
        }
        Text {
          text: "↑ " + net.rate(net.host.txRate)
          color: net.dotmatrix ? DotMatrix.Palette.fg : net.host.foreground
          font.family: net.face
          font.pixelSize: 11
          font.letterSpacing: net.dotmatrix ? 1 : 0
        }
      }
    }

    DotMatrix.DotScope {
      width: parent.width
      height: 40
      series: net.host.rxHistory
      secondary: net.host.txHistory
    }
  }
}

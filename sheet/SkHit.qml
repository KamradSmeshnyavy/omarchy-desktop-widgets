import QtQuick

// Цель клика и клавиатуры: MouseArea, у которой нажатие с клавиатуры (KeyNav → kbdPress) и мышью — один сигнал hit.
// (KeyNav шлёт MouseArea.clicked с объектом вместо события — Qt его не принимает, поэтому — свой kbdPress.)
MouseArea {
  signal hit()
  function kbdPress() { hit() }
  property real kbdRadius: Sk.n("radius", 4)
  hoverEnabled: true
  cursorShape: Qt.PointingHandCursor
  onClicked: hit()
}

import QtQuick

// Погода на столе (виджет weather; данные — open-meteo через Widgets.qml, город — weatherCity). Вид — по мотивам
// карточки погоды Bruteon (Darkkal44, облик со скриншота, код свой): слева значок погоды и крупная температура,
// черта, справа — «📍 Город», описание и две пастельные фишки (влажность, ветер). Подложку рисует WidgetCard по стилю.
Item {
  id: wx

  required property var host
  readonly property var w: host.weather
  readonly property bool ok: !!w && w.error === undefined && w.temp !== undefined
  readonly property color ink: host.foreground
  readonly property string mono: Qt.fontFamilies().indexOf("JetBrainsMono Nerd Font") !== -1 ? "JetBrainsMono Nerd Font" : host.fontFamily
  readonly property string unit: String(host.value("weatherUnits")) === "fahrenheit" ? "°F" : "°"

  function describe(code) {
    var t = [[[0], "\u{F0599}", "Clear", "Ясно"], [[1, 2], "\u{F0595}", "Partly cloudy", "Переменная облачность"],
             [[3], "\u{F0590}", "Overcast", "Пасмурно"], [[45, 48], "\u{F0591}", "Fog", "Туман"],
             [[51, 53, 55, 56, 57], "\u{F0597}", "Drizzle", "Морось"], [[61, 63, 65, 66, 67, 80, 81, 82], "\u{F0596}", "Rain", "Дождь"],
             [[71, 73, 75, 77, 85, 86], "\u{F0598}", "Snow", "Снег"], [[95, 96, 99], "\u{F0593}", "Thunderstorm", "Гроза"]]
    for (var i = 0; i < t.length; i++) if (t[i][0].indexOf(code) !== -1) return { glyph: t[i][1], text: host.tr(t[i][2], t[i][3]) }
    return { glyph: "\u{F0590}", text: "" }
  }

  width: 330
  height: 110

  Text {
    visible: !wx.ok
    anchors.centerIn: parent
    width: parent.width - 30
    wrapMode: Text.Wrap
    horizontalAlignment: Text.AlignHCenter
    text: wx.w && wx.w.error ? wx.w.error : wx.host.tr("Set a city: Customizer → Widgets → Dashboard: weather city", "Задай город: Customizer → Виджеты → Дашборд: город")
    color: wx.ink; opacity: 0.7
    font.family: wx.mono; font.pixelSize: 11
  }

  Row {
    visible: wx.ok
    anchors.centerIn: parent
    spacing: 18
    Row {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 12
      Text { anchors.verticalCenter: parent.verticalCenter; text: wx.ok ? wx.describe(wx.w.code).glyph : ""; color: wx.ink; font.family: wx.host.iconFamily; font.pixelSize: 34 }
      Text { anchors.verticalCenter: parent.verticalCenter; text: wx.ok ? Math.round(wx.w.temp) + wx.unit : ""; color: wx.ink; font.family: wx.mono; font.pixelSize: 34; font.bold: true }
    }
    Rectangle { width: 1.5; height: 62; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(wx.ink.r, wx.ink.g, wx.ink.b, 0.25) }
    Column {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 5
      Row {
        spacing: 6
        Text { text: "\u{F034E}"; color: wx.ink; font.family: wx.host.iconFamily; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
        Text { text: wx.ok ? String(wx.w.city || "") : ""; color: wx.ink; font.family: wx.mono; font.pixelSize: 13; font.bold: true }
      }
      Text { text: wx.ok ? wx.describe(wx.w.code).text : ""; color: wx.ink; font.family: wx.mono; font.pixelSize: 11 }
      Row {
        spacing: 6
        Repeater {
          model: wx.ok ? [["\u{F058C}", (wx.w.humidity !== undefined ? Math.round(wx.w.humidity) : "–") + "%", "#dcc4ec"],
                          ["\u{F059D}", (wx.w.wind !== undefined ? Math.round(wx.w.wind) : "–") + " km/h", "#c5e1a5"]] : []
          Rectangle {
            required property var modelData
            width: chip.implicitWidth + 14; height: 18; radius: 9
            color: modelData[2]; border.width: 1.5; border.color: wx.ink
            Row { id: chip; anchors.centerIn: parent; spacing: 4
              Text { text: modelData[0]; color: "#161110"; font.family: wx.host.iconFamily; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter }
              Text { text: modelData[1]; color: "#161110"; font.family: wx.mono; font.pixelSize: 8; font.bold: true; anchors.verticalCenter: parent.verticalCenter } }
          }
        }
      }
    }
  }
}

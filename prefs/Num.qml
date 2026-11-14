import QtQuick


// Из glyph-rice (GPL-3.0), вид — по активному райсу (PTheme). цифры и короткие слова: Doto, круглые точки (ROND 100). Не мельче 26px.
// Рамка — как line-height .85 в концепте: lineHeight у однострочного Text не работает, поэтому отрицательные поля
// (строка Doto 1.2em → .85em). Свой отступ — `topPadding: lead + 8`
Text {
    textFormat: Text.PlainText
    readonly property real lead: -0.175 * font.pixelSize
    font { family: PTheme.dot; pixelSize: 44; weight: PTheme.doto ? Font.Black : Font.Bold; variableAxes: PTheme.doto ? ({ "ROND": 100, "wght": 900 }) : ({}) }
    topPadding: lead
    bottomPadding: lead
    color: PTheme.fg
}

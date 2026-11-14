import QtQuick


// Из glyph-rice (GPL-3.0), вид — по активному райсу (PTheme). метка: Space Mono капсом, трекинг .14em, серая. Размер — px (а не font.pixelSize: трекинг считается от него)
Text {
    textFormat: Text.PlainText // в подписях чужие строки (сети, устройства, окна, треки): AutoText грузил бы из них <img src="http://…">
    property real px: 12
    font { family: PTheme.mono; pixelSize: px; letterSpacing: PTheme.upper ? px * 0.14 : px * 0.02; capitalization: PTheme.upper ? Font.AllUppercase : Font.MixedCase; weight: PTheme.labelWeight }
    color: PTheme.grey
}

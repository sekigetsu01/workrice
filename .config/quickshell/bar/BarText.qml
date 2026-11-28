import QtQuick
import "../"
import "fmt.js" as F

// The bar's text: JetBrainsMono Nerd Font, bold, sized and spaced to the bar's scale so it lines up on every screen.
Text {
    id: t

    property real px: 11.1 * Sys.barScale
    property bool emoji: false
    readonly property real pt: (emoji ? px * 136 / 109 : px) * 0.75

    visible: text !== ""
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: "JetBrainsMono Nerd Font"
    font.bold: true
    font.pointSize: pt
    font.hintingPreference: Font.PreferVerticalHinting
    font.letterSpacing: emoji ? 0 : F.adv(px, false, Sys.barScale) - tm.advanceWidth / 10

    TextMetrics {
        id: tm
        text: "0000000000"
        font.family: "JetBrainsMono Nerd Font"
        font.bold: true
        font.pointSize: t.pt
        font.hintingPreference: Font.PreferVerticalHinting
    }
}

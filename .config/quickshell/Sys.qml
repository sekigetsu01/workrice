pragma Singleton
import Quickshell

// Shared settings: the terminal panels open things in (kitty), and the bar's height and scale (the same size on
// screen whatever QT_SCALE_FACTOR is).
Singleton {
    readonly property string terminal: "kitty"
    property int barH: 22
    // the bar's size on screen, whatever QT_SCALE_FACTOR is
    readonly property real barSize: 1.265
    readonly property real barScale: barSize / (Number(Quickshell.env("QT_SCALE_FACTOR")) || 1)
    function barPx(n) { return Math.round(n * barScale); }
}

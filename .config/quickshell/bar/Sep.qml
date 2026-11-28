import QtQuick
import "../"

// The dim | between groups of modules on the bar.
Mod {
    text: "|"
    px: 15 * Sys.barScale
    fg: Pal.color8
    opacity: 0.6
    line: false
    padL: 1
}

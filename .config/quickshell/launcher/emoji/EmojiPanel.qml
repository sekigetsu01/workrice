import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../fuzzy.js" as Fuzzy
import "../highlight.js" as Hl

// The emoji picker (Super+`): search by name, Enter copies the emoji; starred ones stay at the top.
// The list is ~/.local/share/characters/emojis
PickerPanel {
    id: root

    theme: LauncherThemeBase {
        id: theme
        panelW: 360
        searchBarH: 52
    }
    placeholder: "Search emojis..."
    status: items.length > 0 ? items.length + " emojis" : ""
    itemKey: "emoji"

    readonly property string favsJson: JSON.stringify(LauncherPrefs.data.emojisFavs || {})
    readonly property var favs: JSON.parse(favsJson)
    property var emojis: []

    onQueryChanged: rebuild()
    onFavsChanged: rebuild(true)
    onPick: it => {
        if (!it)
            return;
        Quickshell.execDetached(["wl-copy", "--", it.emoji]);
        Quickshell.execDetached(["notify-send", "-a", "Emoji", it.emoji + " Copied to clipboard!"]);
        hide();
    }
    onFav: it => {
        const f = Object.assign({}, favs);
        if (f[it.emoji])
            delete f[it.emoji];
        else
            f[it.emoji] = it.desc;
        LauncherPrefs.save({ emojisFavs: f });
    }

    function rebuild(keep) {
        const q = query.trim();
        let res;
        if (q === "") {
            res = emojis.filter(e => favs[e.emoji]).concat(emojis.filter(e => !favs[e.emoji]));
        } else {
            res = [];
            for (const e of emojis) {
                const m = Fuzzy.match(q, e.desc);
                if (m)
                    res.push({ emoji: e.emoji, desc: e.desc, hl: m.indices, score: m.score, fav: favs[e.emoji] ? 1 : 0 });
            }
            res.sort((a, b) => b.fav - a.fav || b.score - a.score);
        }
        setItems(res, keep);
    }

    FileView {
        path: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/characters/emojis"
        onLoaded: {
            const out = [];
            for (const line of text().split("\n")) {
                const t = line.trim(), sp = t.indexOf(" ");
                if (sp > 0)
                    out.push({ emoji: t.substring(0, sp), desc: t.substring(sp + 1).trim(), hl: [] });
            }
            root.emojis = out;
            root.rebuild();
        }
    }

    delegate: PickerRow {
        id: r
        star: true
        starred: !!root.favs[r.modelData.emoji]

        Item {
            width: 20
            height: 20
            Layout.alignment: Qt.AlignVCenter
            Text {
                anchors.centerIn: parent
                text: r.modelData.emoji
                font.pixelSize: 16
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.StyledText
                text: Hl.markup(r.modelData.desc, r.modelData.hl, theme.clrMatch)
                font.pixelSize: 13
                font.family: "monospace"
                color: r.isSel ? theme.clrTextPrim : theme.clrTextSecond
                Behavior on color {
                    ColorAnimation {
                        duration: 80
                    }
                }
            }
        }
    }
}

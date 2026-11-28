import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../"
import "../"
import "../fuzzy.js" as Fuzzy
import "../highlight.js" as Hl

// The app launcher (Super+d): every app with a .desktop file, starred ones first, then the ones you open most (and
// lately). Hidden apps (NoDisplay, apphide) are left out. Enter opens it; terminal apps open in kitty
PickerPanel {
    id: root

    theme: LauncherThemeBase {
        id: theme
        panelW: 360
        searchBarH: 52
    }
    placeholder: "Search apps..."
    status: items.length > 0 ? items.length + " apps" : ""

    readonly property var freq: LauncherPrefs.data.freq || ({})
    readonly property var favs: LauncherPrefs.data.favs || ({})
    readonly property bool prefsReady: LauncherPrefs.ready
    property var apps: []
    property bool stale: true

    onQueryChanged: rebuild()
    onPrefsReadyChanged: rebuild(true)
    onActivated: {
        if (stale)
            rebuild();
        appListProc.running = true;
    }
    onPick: it => {
        if (!it || it.app.exec.trim() === "")
            return;
        const a = it.app;
        const single = { "vesktop.desktop": "vesktop" }[a.id];
        Quickshell.execDetached(["sh", "-c", 'cd "$HOME" && exec "$@"', "sh"].concat(
            single ? [Quickshell.env("HOME") + "/.config/mango/scripts/raise", single, "sh", "-c", a.exec]
            : a.terminal ? [Sys.terminal, "-e", "sh", "-c", a.exec] : ["sh", "-c", a.exec]));
        const f = Object.assign({}, freq);
        f[a.name] = { count: ((f[a.name] || {}).count || 0) + 1, lastUsed: Date.now() };
        LauncherPrefs.save({ freq: f });
        stale = true;
        hide();
    }
    onFav: it => {
        const f = Object.assign({}, favs);
        if (f[it.app.name])
            delete f[it.app.name];
        else
            f[it.app.name] = true;
        LauncherPrefs.save({ favs: f });
        rebuild(true);
    }

    function freqScore(name) {
        const e = freq[name];
        if (!e || !e.count)
            return 0;
        const days = (Date.now() - (e.lastUsed || 0)) / 86400000;
        return e.count * (days < 1 ? 4 : days < 7 ? 2 : days < 30 ? 1 : days < 90 ? 0.5 : 0.25);
    }

    function rebuild(keep) {
        stale = false;
        const q = query.trim(), res = [];
        for (const a of apps) {
            const m = q === "" ? { score: 0, indices: [] } : Fuzzy.match(q, a.name);
            if (m)
                res.push({ name: a.name, app: a, score: m.score, hl: m.indices, fav: favs[a.name] ? 1 : 0, f: freqScore(a.name), last: (freq[a.name] || {}).lastUsed || 0 });
        }
        res.sort((a, b) => b.fav - a.fav
            || q !== "" && (b.score + Math.min(8, 2 * Math.log2(1 + b.f))) - (a.score + Math.min(8, 2 * Math.log2(1 + a.f)))
            || b.f - a.f
            || b.last - a.last
            || a.app.name.localeCompare(b.app.name));
        setItems(res, keep);
    }

    function letterColor(name) {
        let hash = 0;
        for (let i = 0; i < name.length; i++)
            hash = (hash * 31 + name.charCodeAt(i)) & 0xffffffff;
        return Qt.hsla((Math.abs(hash) % 360) / 360, 0.30, 0.28, 1.0);
    }

    Process {
        id: appListProc
        property string stamp: ""
        property string newStamp: ""
        property var buf: []
        command: ["sh", "-c", "last=$1; set -- \"$HOME/.local/share/applications\" \"$HOME/.local/share/flatpak/exports/share/applications\" /var/lib/flatpak/exports/share/applications /usr/share/applications; " +
            "now=$(date +%s); [ -n \"$last\" ] && [ -z \"$(find \"$@\" -newermt \"@$last\" \\( -type d -o -name '*.desktop' \\) -print -quit 2>/dev/null)\" ] && exit 0; " +
            "echo \"@@STAMP $((now - 1))\"; " +
            "for d in \"$@\"; do find \"$d\" -name '*.desktop' 2>/dev/null; done | xargs -r -d '\\n' awk '" + "BEGINFILE { n=\"\"; e=\"\"; ic=\"\"; nd=\"\"; hd=\"\"; tm=\"\"; inEntry=0 }" + "/^\\[Desktop Entry\\]/ { inEntry=1; next }" + "/^\\[/ { inEntry=0 }" + "inEntry && /^Name=/ && n==\"\"   { n=substr($0,6) }" + "inEntry && /^Exec=/ && e==\"\"   { e=substr($0,6) }" + "inEntry && /^Icon=/ && ic==\"\"  { ic=substr($0,6) }" + "inEntry && /^NoDisplay=/         { nd=substr($0,11) }" + "inEntry && /^Terminal=/          { tm=substr($0,10) }" + "inEntry && /^Hidden=/            { hd=substr($0,8) }" + "ENDFILE {" + "  if (n!=\"\") {" + "    gsub(/ *%[a-zA-Z]/, \"\", e); id=FILENAME; sub(/.*\\//, \"\", id);" + "    print n \"\\t\" e \"\\t\" ic \"\\t\" tm \"\\t\" id \"\\t\" ((nd==\"true\" || hd==\"true\") ? 1 : 0)" + "  }" + "}' 2>/dev/null", "sh", stamp]
        onRunningChanged: if (running) {
            buf = [];
            newStamp = "";
        }
        stdout: SplitParser {
            onRead: line => {
                if (line.trim() === "")
                    return;
                if (line.startsWith("@@STAMP ")) {
                    appListProc.newStamp = line.slice(8);
                    return;
                }
                const p = line.split("\t");
                if (!p[0])
                    return;
                appListProc.buf.push({
                    name: p[0],
                    exec: p[1] || "",
                    icon: p[2] || "",
                    terminal: (p[3] || "").toLowerCase() === "true",
                    id: p[4] || "",
                    hidden: p[5] === "1"
                });
            }
        }
        onExited: {
            if (newStamp === "")
                return;
            stamp = newStamp;
            const seenId = {}, seen = {}, deduped = [];
            for (const a of buf) {
                if (a.id !== "") {
                    if (seenId[a.id])
                        continue;
                    seenId[a.id] = true;
                }
                if (a.hidden || seen[a.name])
                    continue;
                seen[a.name] = true;
                deduped.push(a);
            }
            root.apps = deduped;
            buf = [];
            root.rebuild(true);
        }
    }

    delegate: PickerRow {
        id: r
        star: true
        starred: !!root.favs[r.modelData.app.name]

        Item {
            width: 20
            height: 20
            Layout.alignment: Qt.AlignVCenter
            Rectangle {
                anchors.fill: parent
                radius: 4
                color: root.letterColor(r.modelData.app.name)
                visible: iconImg.status !== Image.Ready
                Text {
                    anchors.centerIn: parent
                    text: r.modelData.app.name.charAt(0).toUpperCase()
                    font.pixelSize: 10
                    font.bold: true
                    color: Pal.fgOnDark
                }
            }
            Image {
                id: iconImg
                anchors.fill: parent
                source: r.modelData.app.icon !== "" ? "image://icon/" + r.modelData.app.icon : ""
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
                visible: status === Image.Ready
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.StyledText
                text: Hl.markup(r.modelData.app.name, r.modelData.hl, theme.clrMatch)
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

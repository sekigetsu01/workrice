.pragma library

// A name with its matched letters bold, underlined and coloured, for the launcher panels' lists

function markup(text, matches, colour) {
    const hits = new Set(matches);
    let out = "";
    for (let i = 0; i < text.length; i++) {
        let ch = text[i];
        let hit = hits.has(i);
        const c = text.charCodeAt(i);
        if (c >= 0xD800 && c <= 0xDBFF && i + 1 < text.length) {
            hit = hit || hits.has(i + 1);
            ch += text[++i];
        }
        ch = ch === "&" ? "&amp;" : ch === "<" ? "&lt;" : ch === ">" ? "&gt;" : ch === " " ? "&nbsp;" : ch;
        out += hit ? `<b><u><font color="${colour}">${ch}</font></u></b>` : ch;
    }
    return out;
}
